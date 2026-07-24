## HERE IS THE START OF OUR PROTOTYPE

library(ellmer)
library(bslib)
library(shiny)
library(DBI)
library(duckdb)
library(jsonlite)
library(readr)
library(markdown)
library(rlang)
library(here) # fixes directory issues with Shiny app
library(ragnar)

# function to normalize metadata (e.g. dataset a uses "desc" key but dataset b uses "human_label" b)
normalize_metadata <- function(meta, meta_path) {
  col_list <- meta$columns %||% list()
  col_string <- "N/A"
  if (length(col_list) > 0) {
    lines <- sapply(col_list, function(c) {
      name <- c$name %||% c$variable_code %||% "No name"
      desc <- c$desc %||% c$human_label %||% "No description."
      
      # used to clean acs metadata so the chatbot doesn't get confused over the !! and choose wrong columns
      clean_desc <- gsub("Estimate!!Total:!!", "Total for ", desc)
      clean_desc <- gsub("!!", " ", clean_desc)
      
      paste0("  - ", name, ": ", clean_desc)
    })
    col_string <- paste(lines, collapse = "\n")
  }
  
  return(list(
    file_name = meta$file_name %||% basename(meta_path),
    file_path = meta$file_path %||% "N/A",
    desc = meta$desc %||% "N/A",
    organization = meta$organization %||% "N/A",
    geo_coverage = meta$geographic_level %||% "N/A",
    time_coverage = meta$time_coverage %||% "N/A",
    locality_fips_col = meta$spatial_alignment$locality_fips %||% "GEOID",
    columns_schema = col_string,
    url = meta$url_source %||% "N/A"
  ))
}

# =========================================================================
# GLOBAL INITIALIZATION (Runs once when app boots)
# =========================================================================

# 1. Load our structural lookup files using here() to prevent working directory issues
VIRGINIA_LOCALITIES <- read.csv(here("data/outcome/virginia_localities.csv"), stringsAsFactors = FALSE)
SCHOOL_BRIDGES      <- read.csv(here("data/outcome/Urban-Institute/institution-locality_relationship_table.csv"), stringsAsFactors = FALSE)

# Force names to lowercase to make string matching bulletproof
VIRGINIA_LOCALITIES$alias <- tolower(VIRGINIA_LOCALITIES$alias)

# 2. Spin up the background serverless DuckDB engine
DB_CON <<- dbConnect(duckdb())

# EXTRACTION: We load our data tools script here
source(here("programs/chatbot/data_tools.R"))

# 3. Clean up the database connection gracefully if the Shiny app stops
onStop(function() {
  dbDisconnect(DB_CON, shutdown = TRUE)
})

registry_store_path <- here("data", "outcome", "registry_store.duckdb")

if (!file.exists(registry_store_path)) {
  stop(
    "The registry store does not exist. Run : ",
    "Rscript programs/chatbot/build_registry_store.R"
  )
}

REGISTRY_STORE <- ragnar_store_connect(
  registry_store_path,
  read_only = TRUE
)

# UI ----------------------------------------------------------------------

ui <- page_fixed(
  # bslib theme
  theme = bs_theme(version = 5, bootswatch = "yeti"),
  
  div (
    # center the chatbot box
    class = "d-flex flex-column justify-content-center min-vh-100",
    
    # this part is UI for the export and import chat log buttons
    div(
      class = "d-flex gap-2 mb-2",
      downloadButton("export_log", "Save Chat Session", class = "btn-outline-primary w-50"),
      fileInput("import_log", NULL, accept = c(".json"), buttonLabel = "Upload Previous Chat Session", placeholder = "No file selected")
    ),
    
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
        height = "500px",       
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
  
  # REGISTRATION: Register our Data Tool with the chat object
  chat_obj$register_tool(summarize_data_tool)
  
  # Replaced with a clean, centered starter label:
  chat_log <- reactiveVal("<div class='text-center text-muted large my-2'><strong>Conversation Started</strong></div>")
  
  # cache to save previous metadata paths, user prompts, and solve ambiguations between counties/cities
  cache <- reactiveValues(
    last_metadata_path = NULL,
    last_fips = NULL,
    last_locality_name = NULL
  )
  
  # only update chat box if user hits submit button and user has something in prompt input box
  observeEvent(input$submit_button, {
    req(input$user_prompt) 
    
    user_prompt_clean <- tolower(trimws(input$user_prompt))
    
    # -------------------------------------------------------------------------
    # DEFENSIVE INITIALIZATION: Ensure these always exist in all logical paths
    # -------------------------------------------------------------------------
    target_fips            <- NULL
    target_locality_name   <- NULL
    is_follow_up           <- FALSE
    matched_metadata_paths <- character()
    top_k                  <- 3 # Guaranteed fallback if vector search is bypassed
    
      
      # =========================================================================
      # MILESTONE 1: LOCALITY MATCHING (MOVED UP TO RUN FIRST)
      # =========================================================================
      for (i in 1:nrow(VIRGINIA_LOCALITIES)) {
        if (grepl(VIRGINIA_LOCALITIES$alias[i], user_prompt_clean)) {
          target_fips <- sprintf("%05d", as.integer(VIRGINIA_LOCALITIES$fips[i]))
          target_locality_name <- VIRGINIA_LOCALITIES$locality[i]
          break
        }
      }
      
      # =========================================================================
      # INTENT GATEKEEPER: FOLLOW-UP QUERY (STEP 4 REUSE OR ROUTE RULE)
      # =======================================g==================================
      if (length(chat_obj$get_turns()) > 0 && !is.null(cache$last_metadata_path)) {
        classification_chat <- chat_obj$clone()$set_turns(list())
        classification_prompt <- sprintf(
          "You are an internal routing system. The user just asked: '%s'. Does this question sound like a short conversational follow-up to the previous topic (e.g., asking about a different year, different county, or related metric) or is it a completely new, distinct topic? Answer with EXACTLY ONE WORD: 'YES' if it is a follow-up, or 'NO' if it is a new topic.",
          user_prompt_clean
        )
        intent_response <- classification_chat$chat(classification_prompt, echo = "none")
        
        if (grepl("YES", toupper(intent_response))) {
          is_follow_up <- TRUE
          message("LLM Gatekeeper: Detected follow-up query. Bypassing vector search.")
        }
      }
      
      # =========================================================================
      # ROUTING EXECUTION
      # =========================================================================
      if (is_follow_up) {
        # Step 4 Rule: "What about 2024?" reuses previous dataset
        matched_metadata_paths <- cache$last_metadata_path
        
        # If user didn't specify a new county, carry over the old one
        if (is.null(target_fips) && !is.null(cache$last_fips)) {
          target_fips <- cache$last_fips
          target_locality_name <- cache$last_locality_name
        }
      } else {
        # Step 4 Rule: "Tell me about chickenpox in Accomack" performs new routing
        semantic_results <- ragnar_retrieve(
          REGISTRY_STORE,
          text = user_prompt_clean,
          top_k = top_k,
          deoverlap = FALSE
        )
        candidates <- semantic_results %>% 
          dplyr::distinct(dataset_id, metadata_path, .keep_all = TRUE) %>% 
          head(top_k)
        
        message("User prompt: \n - ", user_prompt_clean, "\n")
        
        if (nrow(candidates) > 0) {
          matched_metadata_paths <- candidates$metadata_path[[1]]
          message("Top candidate: \n - ", matched_metadata_paths, "\n")
          if (nrow(candidates) > 1) {
            skipped <- candidates$metadata_path[2:nrow(candidates)]
            formatted_skipped <- paste0("  - ", skipped, collapse = "\n")
            message("Skipped Runner-ups:\n", formatted_skipped)
          }
        }
      }
  
    
    # Initialize the data context tracker for Milestone 3
    data_context <- ""
    
    # =========================================================================
    # MILESTONE 2: DUCKDB DIRECT-FROM-DISK EXTRACTION LOOP
    # =========================================================================
    if (length(matched_metadata_paths) > 0 && !is.null(target_fips)) {
      # Path 1: metadata path and fips is found
      data_context <- paste0("Targeting Locality: ", target_locality_name, " (FIPS: ", target_fips, ")\n\n")
      
      for (meta_path in matched_metadata_paths) {
        # gets the raw metadata json and normalizes it with normalize_metadata function
        raw_json <- jsonlite::fromJSON(txt = readLines(here(meta_path), warn = FALSE), simplifyVector = FALSE)
        metadata <- normalize_metadata(raw_json, meta_path)
        
        # build list of columns that will be used
        col_list <- raw_json$columns %||% list()
        defined_columns <- sapply(col_list, function(c) c$name %||% c$variable_code)
        
        # make sure the locality is just one code so the querying doesn't break
        fips_col <- as.character(metadata$locality_fips_col)[1]
        if (is.null(fips_col) || length(fips_col) == 0 || is.na(fips_col) || fips_col == "") {
          fips_col <- "GEOID"
        }
        safe_select_columns <- unique(c("year", fips_col, defined_columns))
        
        # Inject source URL into structured context for citations
        data_context <- paste0(data_context, "Dataset Baseline Description: ", metadata$desc, "\nSource URL: ", metadata$url, "\nDataset Column Definitions Legend:\n", metadata$columns_schema, "\n\n")
        
        raw_file_absolute_path <- here(metadata$file_path)
        
        # path for ccd files
        if (!is.null(metadata$file_name) && metadata$file_name %in% c("2020-2024_ccd_directory.csv", "2020-2024_ccd_enrollment.csv")) {
          
          # see if the target fips matches any fips inside the school bridges csv (school district spans 2 counties)
          matching_bridges <- SCHOOL_BRIDGES[as.integer(SCHOOL_BRIDGES$locality_fips) == as.integer(target_fips), ]
          if (nrow(matching_bridges) > 0) {
            target_leaid <- as.character(matching_bridges$institution_id[1])
            relationship <- matching_bridges$relationship_type[1]
            
            # query for school districts spanning across two counties
            query <- sprintf("SELECT * FROM '%s' WHERE leaid = '%s'", raw_file_absolute_path, target_leaid)
            records <- dbGetQuery(DB_CON, query)
            
            if (relationship == "shared") {
              data_context <- paste0(data_context, "⚠️ NOTE TO ASSISTANT: This data belongs to a shared regional school division encompassing multiple political jurisdictions. Do not attribute metrics solely to one county.\n")
            }
          } else {
            # query for if the school district doesn't span across two counties
            query <- sprintf("SELECT * FROM '%s' WHERE %s = '%s'", raw_file_absolute_path, fips_col, target_fips)
            records <- dbGetQuery(DB_CON, query)
          }
        } else {
          # query for all other datasets other than ccd
          query <- sprintf(
            "SELECT * FROM '%s' WHERE CAST(%s AS VARCHAR) = '%s' OR TRY_CAST(%s AS BIGINT) = %d", 
            raw_file_absolute_path, 
            fips_col, target_fips,
            fips_col, as.integer(target_fips)
          )
          records <- dbGetQuery(DB_CON, query) 
        }
        
        # drops all columns not used
        available_cols <- intersect(safe_select_columns, names(records))
        if(length(available_cols) > 0) {
          records <- records[, available_cols, drop = FALSE]
        }
        
        # loops through the rows that match the query results and store them into a vector to be read in data_context
        if (nrow(records) > 0) {
          record_string <- jsonlite::toJSON(records, auto_unbox = TRUE, pretty = FALSE)
          data_context <- paste0(data_context, "Dataset [", metadata$file_name, "] Minified JSON Records:\n", record_string, "\n\n")
        }
      }
    } else if (length(matched_metadata_paths) > 0 && is.null(target_fips)) {
      # Path 2: metadata path is found but FIPS is not
      
      data_context <- "The user is asking a structural or metadata question about these specific dataset blueprints:\n\n"
      
      for (meta_path in matched_metadata_paths) {
        raw_json <- jsonlite::fromJSON(txt = readLines(here(meta_path), warn = FALSE), simplifyVector = FALSE)
        metadata <- normalize_metadata(raw_json, meta_path)
        
        dataset_manifest <- paste0(
          "--- DATASET PROFILE ---\n",
          "File: ", metadata$file_name, "\n",
          "Description: ", metadata$desc, "\n",
          "Source: ", metadata$organization, "\n",
          "Geographic Coverage: ", metadata$geo_coverage, "\n",
          "Temporal Coverage: ", metadata$time_coverage, "\n",
          "Source URL: ", metadata$url, "\n",
          "Dataset Columns:\n", metadata$columns_schema, "\n",
          "---------------------------------\n\n"
        )
        data_context <- paste0(data_context, dataset_manifest)
      }
    } else {
      # Path 3: neither metadata path nor fips is found
      
      # use semantic retrieval to find relevant master registry information
      semantic_results <- ragnar_retrieve(
        REGISTRY_STORE, 
        text = input$user_prompt, 
        top_k = top_k,
        deoverlap = FALSE
      )
      
      # if there were any matches, grabs the texts from results and puts into data_context
      if (length(semantic_results) > 0) {
        # Extract the matched text content safely depending on data structure
        retrieved_text <- c()
        if (is.data.frame(semantic_results)) {
          retrieved_text <- semantic_results$text
        } else if (is.list(semantic_results)) {
          retrieved_text <- sapply(semantic_results, function(res) res$text %||% "")
        }
        
        combined_chunks <- paste(retrieved_text, collapse = "\n\n---\n\n")
        
        data_context <- paste0(
          "The following relevant excerpts were retrieved semantically from the registry database:\n\n",
          combined_chunks, 
          "\n\nUse this information to answer the user's question or help direct them to the right data."
        )
      }
    }
    # =========================================================================
    # AI EXECUTION & STREAMING HAND-OFF
    # =========================================================================
      resolved_prompt <- input$user_prompt
    
    # System prompt directing the LLM how to handle current context vs historical turns
    final_prompt <- sprintf(
      "You are a helpful data assistant. Format your response in clear and precise sentence form. Do not add irrelevant information unless the prompt asks for it. 
      
=== CITATIONS ===
If a Source URL is provided in the New Context, you MUST cite it at the end of your response using EXACTLY this markdown format: (URL). 
CRITICAL RULE: Do NOT use special citation brackets like 【 or 】. Use only standard markdown brackets.

=== Performing Calculations ===
1. Use data tools registered to perform calculations.
2. Do not calculate anything by yourself without data tools.
3. Only calculate for sum, count, average, max, and min

=== RECONCILING CONTEXT AND HISTORY ===
1. If the 'New Context' block below contains data, use it as your primary source of truth.
2. If the 'New Context' block is empty, inspect your active conversation history. If the user's question is a follow-up (such as asking about a different year, different county, or related metric for the topic under discussion), use the data previously loaded in your history to answer.
3. If 'New Context' is empty and the question is a completely new topic or dataset, state clearly and politely that you do not have the information in active memory and ask them to specify.

New Context: %s

User Question: %s",
      data_context,
      resolved_prompt
    )
    
    # Call the chat STATEFULLY (We do not clone or wipe turns anymore)
    new_response <- withProgress(message = 'Thinking...', detail = 'Consulting database and our AI...', {
      chat_obj$chat(final_prompt, echo = "none")
    })
    
    # We parse Markdown to HTML BEFORE wrapping it inside a block-level HTML tag, so citations render properly
    parsed_ai_response <- markdown::markdownToHTML(text = new_response, fragment.only = TRUE)
    
    # Sanitize model output before UI injection to make new tab navigation secure
    parsed_ai_response <- gsub("<a href", "<a target='_blank' rel='noopener noreferrer' href", parsed_ai_response, ignore.case = TRUE)
    
    # Build a Right-Aligned User Bubble
    user_bubble <- paste0(
      "<div class='d-flex justify-content-end mb-3'>",
      "  <div class='bg-primary text-white p-2 px-3 rounded-3 shadow-sm' style='max-width: 75%; text-align: left;'>",
      "    ", input$user_prompt,
      "  </div>",
      "</div>"
    )
    
    # Build a Left-Aligned AI Bubble
    ai_bubble <- paste0(
      "<div class='d-flex justify-content-start mb-3'>",
      "  <div class='bg-light text-dark p-2 px-3 rounded-3 border shadow-sm' style='max-width: 75%; text-align: left;'>",
      "    ", parsed_ai_response,
      "  </div>",
      "</div>"
    )
    
    # Combine both new elements and append them smoothly to your visual history string
    updated_history <- paste0(chat_log(), user_bubble, ai_bubble)
    
    chat_log(updated_history)
    
    # Save the current state so our LLM Gatekeeper can reuse them on the next turn
    if (length(matched_metadata_paths) > 0) {
      cache$last_metadata_path <- matched_metadata_paths
    }
    if (!is.null(target_fips)) {
      cache$last_fips <- target_fips
      cache$last_locality_name <- target_locality_name
    }
    
    updateTextInput(session, "user_prompt", value = "")
  })  
  
  # render the new chat along with all the previous dialogues coming before it
  output$ai_response <- renderUI({
    HTML(chat_log()) # Chat log is now pre-rendered HTML, so we don't need to parse again
  })
  
  # =========================================================================
  # CHAT LOG EXPORT HANDLER (USER CAN SAVE FILE TO LAPTOP) /// NEEDS FIXING
  # =========================================================================
  output$export_log <- downloadHandler(
    filename = function() {
      paste("chat-session-", Sys.Date(), ".json", sep = "")
    },
    content = function(file) {
      # Take a complete snapshot of your active reactive values
      session_snapshot <- list(
        saved_chat_text        = chat_log(), 
        last_metadata_path     = cache$last_metadata_path,
        last_locality_name     = cache$last_locality_name,
        last_fips              = cache$last_fips
      )
      
      # Pack it into a structured text file and download it
      jsonlite::write_json(session_snapshot, file, pretty = TRUE, auto_unbox = TRUE)
    }
  )
  
  # =========================================================================
  # CHAT LOG IMPORT HANDLER (USER CAN RELOAD PAST FILE) //// NEEDS FIXING
  # =========================================================================
  observeEvent(input$import_log, {
    req(input$import_log)
    
    # Read the uploaded text file safely
    uploaded_snapshot <- tryCatch({
      jsonlite::fromJSON(input$import_log$datapath, simplifyVector = TRUE)
    }, error = function(e) {
      showNotification("Invalid chat log file format.", type = "error")
      return(NULL)
    })
    
    req(uploaded_snapshot)
    
    # 1. Update the reactiveValues to restore visual HTML history on screen
    chat_log(uploaded_snapshot$saved_chat_text)
    
    # 2. Re-inject all background tracking variables back into the cache
    cache$last_metadata_path      <- uploaded_snapshot$last_metadata_path
    cache$last_locality_name      <- uploaded_snapshot$last_locality_name
    cache$last_fips               <- uploaded_snapshot$last_fips
    
    showNotification("Chat session successfully restored!", type = "message")
  })
  
}


# Launch App ------------------------------------------------------------------

shinyApp(ui, server)