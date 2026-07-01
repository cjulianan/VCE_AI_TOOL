## HERE IS THE START OF OUR PROTOTYPE

library(ellmer)
library(bslib)
library(shiny)
library(DBI)
library(duckdb)
library(jsonlite)
library(readr)
library(markdown)
library(here) # fixes directory issues with Shiny app


# =========================================================================
# GLOBAL INITIALIZATION (Runs once when app boots)
# =========================================================================

# 1. Load our structural lookup files using here() to prevent working directory issues
VIRGINIA_LOCALITIES <- read.csv(here("data/outcome/virginia_localities.csv"), stringsAsFactors = FALSE)
SCHOOL_BRIDGES      <- read.csv(here("data/outcome/Urban-Institute/institution-locality_relationship_table.csv"), stringsAsFactors = FALSE)

# Force names to lowercase to make string matching bulletproof
VIRGINIA_LOCALITIES$alias <- tolower(VIRGINIA_LOCALITIES$alias)

# View(VIRGINIA_LOCALITIES) # testing it looaded

# 2. Spin up the background serverless DuckDB engine
DB_CON <- dbConnect(duckdb())

# 3. Clean up the database connection gracefully if the Shiny app stops
onStop(function() {
  dbDisconnect(DB_CON, shutdown = TRUE)
})



# UI ----------------------------------------------------------------------

ui <- page_fixed(
  # bslib theme
  theme = bs_theme(version = 5, bootswatch = "yeti"),
  
  div (
    # center the chatbot box
    class = "d-flex flex-column justify-content-center min-vh-100",
    
    card(
      # website banner to match color picked by theme
      card_header(
        class = "bg-primary text-primary-inverse",
        icon("robot"),
        span("VCE AI Tool", class = "fw-bold")
      ),
      
      # website body, where chat is recorded
      card_body(
        uiOutput("ai_response"),
        height = "400px",       
        fillable = FALSE        
      ),
      
      # website footer, where input box and submit button are located
      card_footer(
        layout_columns(
          col_widths = c(10, 2),
          textInput("user_prompt", label = NULL, placeholder = "Ask AI something..."),
          actionButton("submit_button", label = NULL, class = "btn-primary", icon = icon("paper-plane"))
        )
      )
    )
  )
  
)


# Server ------------------------------------------------------------------

server <- function(input, output, session) {
  # set up chatbot parameters
  chat_obj <- chat_openai_compatible(
    model = "gpt-oss-120b",
    base_url = "https://llm-api.arc.vt.edu/api/v1",
    credentials = function() Sys.getenv("VT_ARC_API_KEY")
  )
  
  # keep record of chat log so new responses aren't overwritten
  chat_log <- reactiveVal("Chat Started: <br>")
  
  # cache for when user clarifies about ambiguous county/city (ex. fairfax county or fairfax city)
  cache <- reactiveValues(
    last_metadata_path = NULL,
    cached_intent_phrase = NULL,
    pending_disambiguation = FALSE
  )
  
  # only update chat box if user hits submit button and user has something in prompt input box
  observeEvent(input$submit_button, {
    req(input$user_prompt) 
    
    # =========================================================================
    # MILESTONE 1: DISAMBIGUATION GATEKEEPER
    # =========================================================================
    
    # This shouldd take care of when a user asks about one of these ambiguoous areas (the code stops and asks)
    # the way its supposed to, but context is not updated
    
    user_prompt_clean <- tolower(trimws(input$user_prompt))
    collision_words <- c("richmond", "roanoke", "fairfax")
    
    # check first if there is a pending disambiguation from user's last prompt
    if (isTRUE(cache$pending_disambiguation)) {
      # set the current metadata path to whatever was retrieved from last prompt
      matched_metadata_paths <- cache$last_metadata_path

      
      # the new prompt will be whatever prompt was cached from previous prompt combined with the new prompt where user clarifies
      combined_prompt <- paste(cache$cached_intent_phrase, user_prompt_clean)
      user_prompt_clean <- combined_prompt
      
    } else {
      master_registry <- jsonlite::fromJSON(txt = readLines(here("data/outcome/master_registry.json"), warn = FALSE), simplifyVector = FALSE)
      matched_metadata_paths <- c()
      
      for (dataset in master_registry$routing_registry) {
        for (keyword in dataset$keywords) {
          if (grepl(keyword, user_prompt_clean)) {
            matched_metadata_paths <- c(matched_metadata_paths, dataset$metadata_path)
            break
          }
        }
      }
    }
    
    # here if no new dataset keywords are found, we carry forward the last successfully 
    # queried metadata path from the cache.
    if (length(matched_metadata_paths) == 0 && !is.null(cache$last_metadata_path)) {
      matched_metadata_paths <- cache$last_metadata_path
    }
    
    for (word in collision_words) {
      if (grepl(word, user_prompt_clean)) {
        if (!grepl("city", user_prompt_clean) && !grepl("county", user_prompt_clean)) {
          
          # cache the current metadata path and user prompt and set disambiguation flag to true so next prompt will use the stored cache values
          cache$last_metadata_path <- matched_metadata_paths
          cache$cached_intent_phrase = input$user_prompt
          cache$pending_disambiguation <- TRUE
          
          updated_history <- paste0(
            chat_log(), "<br>",
            "<strong>User:</strong> ", input$user_prompt, "<br>",
            "⚠️ <strong>System Notice:</strong> <i>Ambiguous locality detected. Did you mean ", 
            tools::toTitleCase(word), " City or ", tools::toTitleCase(word), " County? Please clarify.</i><br>"
          )
          chat_log(updated_history)
          updateTextInput(session, "user_prompt", value = "")
          return() 
        }
      }
    }
    
    # =========================================================================
    # MILESTONE 2: DYNAMIC ROUTING & LOCALITY MATCHING
    # =========================================================================
    
    # Match prompt against virginia_localities data frame to find FIPS
    target_fips <- NULL
    target_locality_name <- NULL
    
    for (i in 1:nrow(VIRGINIA_LOCALITIES)) {
      if (grepl(VIRGINIA_LOCALITIES$alias[i], user_prompt_clean)) {
        target_fips <- sprintf("%05d", as.integer(VIRGINIA_LOCALITIES$fips[i]))
        target_locality_name <- VIRGINIA_LOCALITIES$locality[i]
        break
      }
    }
    
    # Initialize the data context tracker
    data_context <- ""
    
    # =========================================================================
    # MILESTONE 3: DUCKDB DIRECT-FROM-DISK EXTRACTION LOOP
    # =========================================================================
    
    # debug statements
    # cat(paste0("MATCHED METADATA PATHS: ", matched_metadata_paths))
    # cat(paste0("TARGET FIPS: ", target_fips))
    # cat(paste0("TARGET LOCALITY NAME", target_locality_name))
    
    
    if (length(matched_metadata_paths) > 0 && !is.null(target_fips)) {
      data_context <- paste0("Targeting Locality: ", target_locality_name, " (FIPS: ", target_fips, ")\n\n")
      
      for (meta_path in matched_metadata_paths) {
        # Load specific dataset metadata passport
        metadata <- jsonlite::fromJSON(txt = readLines(here(meta_path), warn = FALSE), simplifyVector = FALSE)
        
        # Extract the FIPS column name directly from your spatial_alignment block
        fips_col_name <- NULL
        if (!is.null(metadata$spatial_alignment) && !is.null(metadata$spatial_alignment$locality_fips)) {
          fips_col_name <- metadata$spatial_alignment$locality_fips
        }
        
        # Absolute safety fallback: if it's completely missing or blank, default to "fips"
        if (is.null(fips_col_name) || fips_col_name == "") {
          fips_col_name <- "fips" 
        }
        
        raw_file_absolute_path <- here(metadata$file_path)
        
        # Branch if querying school data to hit the bridge table
        if (!is.null(metadata$file_name) && metadata$file_name %in% c("2020-2024_ccd_directory.csv", "2020-2024_ccd_enrollment.csv")) {
          matching_bridges <- SCHOOL_BRIDGES[SCHOOL_BRIDGES$fips == target_fips, ]
          
          if (nrow(matching_bridges) > 0) {
            target_leaid <- matching_bridges$leaid[1]
            relationship <- matching_bridges$relationship_type[1]
            
            query <- sprintf("SELECT * FROM '%s' WHERE leaid = '%s'", raw_file_absolute_path, target_leaid)
            records <- dbGetQuery(DB_CON, query)
            
            if (relationship == "shared") {
              data_context <- paste0(data_context, "⚠️ NOTE TO ASSISTANT: This data belongs to a shared regional school division encompassing multiple political jurisdictions. Do not attribute metrics solely to one county.\n")
            }
          } else {
            query <- sprintf("SELECT * FROM '%s' WHERE %s = '%s'", raw_file_absolute_path, fips_col_name, target_fips)
            records <- dbGetQuery(DB_CON, query)
          }
          
        } else {
          # Standard dataset file path query
          query <- sprintf("SELECT * FROM '%s' WHERE %s = '%s'", raw_file_absolute_path, fips_col_name, target_fips)
          records <- dbGetQuery(DB_CON, query)
        }
        
        # Append found row string to our pipeline context buffer
        if (nrow(records) > 0) {
          record_string <- paste(capture.output(print(records)), collapse = "\n")
          
          # Dynamic label extraction using file_name or file path fallback
          dataset_label <- if(!is.null(metadata$file_name)) metadata$file_name else basename(meta_path)
          
          data_context <- paste0(data_context, "Dataset [", dataset_label, "] Records:\n", record_string, "\n\n")
        }
      }
    }
    
    # =========================================================================
    # AI EXECUTION & STREAMING HAND-OFF
    # =========================================================================
    # resolved prompt to clarify if there is ambiguous city/county
    if (!is.null(cache$cached_intent_phrase)) {
      resolved_prompt <- paste(cache$cached_intent_phrase, "-> Clarified as:", input$user_prompt)
    } else {
      resolved_prompt <- input$user_prompt
    }
    
    final_prompt <- sprintf(
      "You are a helpful data assistant. Use the following data context to answer the user's question accurately. Format your response in clear and precise sentence form. Don't add irrelevant information unless the prompt asks for it. Cite what dataset you used for your source. If the context is empty, say that you don't have the information to help the user.\n\nContext: %s\n\nUser Question: %s",
      data_context,
      resolved_prompt
    )
    cat(final_prompt)
    
    new_response <- chat_obj$chat(final_prompt)
    
    updated_history <- paste0(
      chat_log(), "<br>",
      "<strong>User:</strong> ", input$user_prompt, "<br>",
      "<strong>AI:</strong> <i>", new_response, "</i><br>"
    )
    
    chat_log(updated_history)
    # reset cache and input box
    cache$pending_disambiguation <- FALSE
    cache$cached_intent_phrase   <- NULL
    # Update our long-term baseline cache if we found data during this run
    if (length(matched_metadata_paths) > 0) {
      cache$last_metadata_path <- matched_metadata_paths
    }
    updateTextInput(session, "user_prompt", value = "")
  })
  
  # render the new chat along with all the previous dialogues coming before it
  output$ai_response <- renderUI({
      HTML(markdown::markdownToHTML(text = chat_log(), fragment.only = TRUE))
  })
}

# Launch App ------------------------------------------------------------------

shinyApp(ui, server)
