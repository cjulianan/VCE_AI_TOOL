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
library(stringdist) # helps us do syntactic scoring (doesnt use embeddings - this package mainly solves typos)
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
    columns_schema = col_string
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

# View(VIRGINIA_LOCALITIES) # testing it looaded

# 2. Spin up the background serverless DuckDB engine
DB_CON <- dbConnect(duckdb())

# 3. Clean up the database connection gracefully if the Shiny app stops
onStop(function() {
  dbDisconnect(DB_CON, shutdown = TRUE)
})

REGISTRY_STORE <- ragnar_store_create(
  location = here("data/outcome/registry_store.duckdb"),
  overwrite = TRUE,
  embed = embed_ollama(model = "embeddinggemma:300m")
)

# read markdown
registry_doc <- read_as_markdown(here("data/outcome/master_registry.md"))

# split markdown into chunks
registry_chunks <- markdown_chunk(registry_doc)

# insert chunks into registry store
ragnar_store_insert(REGISTRY_STORE, registry_chunks)

# index to help with retrieval
ragnar_store_build_index(REGISTRY_STORE)

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
  
  # keep record of chat log so new responses aren't overwritten
  ## chat_log <- reactiveVal("Chat Started: <br>") ## OLD LINE 

  # Replaced with a clean, centered starter label:
  chat_log <- reactiveVal("<div class='text-center text-muted large my-2'><strong>Conversation Started</strong></div>") # can adjust size for the text
  
  # cache to save previous metadata paths, user prompts, and solve ambiguations between counties/cities
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
    # the way its supposed to, but context is not updated (Roanoke, Fairfax, Richmond)
    
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
      
      #  Tokenize the clean user prompt into individual words
      user_words <- unlist(strsplit(user_prompt_clean, "\\s+"))
      
      # Setup tracking variables for our numerical scoring engine
      best_overall_score <- 0
      target_metadata_path <- NULL
      similarity_threshold <- 0.75 # 75% similarity required to trigger a match
      
      #  Loop through every dataset in the registry to find the highest match
      for (dataset in master_registry$routing_registry) {
        max_dataset_score <- 0
        
        for (keyword in dataset$keywords) {
          # 1. Force keyword to lowercase to prevent casing mismatches
          keyword_clean <- tolower(keyword)
          
          # 2. DEFENSIVE PHRASE CHECK: If the exact phrase is inside the prompt,
          # we skip the word-splitting math and give it a perfect score
          if (grepl(keyword_clean, user_prompt_clean, fixed = TRUE)) {
            max_keyword_score <- 1.00
          } else {
            # 3. TYPO FALLBACK: Calculate character-distance similarity
            scores <- 1 - stringdist::stringdistmatrix(user_words, keyword_clean, method = "jw")
            max_keyword_score <- max(scores, na.rm = TRUE)
          }
          
          # Keeps track of the highest match word within this specific dataset
          if (max_keyword_score > max_dataset_score) {
            max_dataset_score <- max_keyword_score
          }
        }
        
        # Checks if this dataset is our best-scoring match so far across the whole registry
        if (max_dataset_score > best_overall_score) {
          best_overall_score <- max_dataset_score
          target_metadata_path <- dataset$metadata_path
        }
      }
      
      # Locks in the path ONLY if the highest score clears our confidence threshold
      print(paste0("Similarity Score is: ", best_overall_score))
      if (best_overall_score >= similarity_threshold && !is.null(target_metadata_path)) {
        matched_metadata_paths <- c(matched_metadata_paths, target_metadata_path)
      } else {
        # If no keyword clears the threshold, 
        # fall back to the last successfully used dataset in the cache!
        # (we don't overwrite the context just because we couldnt find a relevant dataset)
        if (!is.null(cache$last_metadata_path)) {
          matched_metadata_paths <- cache$last_metadata_path
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
          
          # updated_history <- paste0(
          #   chat_log(), "<br>",
          #   "<strong>User:</strong> ", input$user_prompt, "<br>",
          #   "⚠️ <strong>System Notice:</strong> <i>Ambiguous locality detected. Did you mean ",
          #   tools::toTitleCase(word), " City or ", tools::toTitleCase(word), " County? Please clarify.</i><br>"
          # )
          
          
          # Construct a centered system alert bubble using Bootstrap flexbox
          system_bubble <- paste0(
            # 'd-flex' opens a flex container; 'justify-content-center' pushes the box to the exact middle
            "<div class='d-flex justify-content-center mb-3'>",
            
            # 'bg-secondary' makes the box dark gray; 'text-white' colors the text; 'rounded-3' rounds the corners
            # 'small' drops font size; 'max-width: 85%' stops the gray bar from completely hitting the card edge
            "  <div class='bg-secondary text-secondary-inverse p-2 px-3 rounded-3 text-center small' style='max-width: 85%;'>",
            "    ⚠️ <strong>System Notice:</strong> <i>Ambiguous locality detected. Did you mean ", 
            tools::toTitleCase(word), " City or ", tools::toTitleCase(word), " County? Please clarify.</i>",
            "  </div>",
            "</div>"
          )
          
          # Append the newly generated system bubble to our master HTML chat string
          updated_history <- paste0(chat_log(), system_bubble)
          
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
    
    # Three paths based on availability of metadata path and fips
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
        
        data_context <- paste0(data_context, "Dataset Baseline Description: ", metadata$desc, "\n", "Dataset Column Definitions Legend:\n", metadata$columns_schema, "\n\n")
        
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
        limit = 3
      )
      
      # if there were any matches, grabs the texts from results and puts into data_context
      if (length(semantic_results) > 0) {
        # Extract the matched text content from the returned list of chunks
        retrieved_text <- sapply(semantic_results, function(res) res$text)
        combined_chunks <- paste(retrieved_text, collapse = "\n\n---\n\n")
        
        data_context <- paste0(
          "The following relevant excerpts were retrieved semantically from the registry database:\n\n",
          combined_chunks, 
          "\n\nUse this information to answer the user's question or help direct them to the right data."
        )
      } else {
        # else set data context as the following
        data_context <- "No direct matches found. Inform the user of what general topics are covered in the available registry."
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
    # cat(final_prompt)
    
    # clear history (doesn't affect cache) so that it doesn't hit character limit from multiple prompts from large datasets such as acs
    stateless_chat <- chat_obj$clone()$set_turns(list())
    # THIS FORCE-TRIGGERS A NATIVE LOADING BAR THE SECOND THE API IS CALLED
    new_response <- withProgress(message = 'Thinking...', detail = 'Consulting database and our AI...', {
      stateless_chat$chat(final_prompt, echo = "none")
    })
    
    # updated_history <- paste0(
    #   chat_log(), "<br>",
    #   "<strong>User:</strong> ", input$user_prompt, "<br>",
    #   "<strong>AI:</strong> <i>", new_response, "</i><br>"
    # )
    
    # Build a Right-Aligned User Bubble
    user_bubble <- paste0(
      # 'justify-content-end' acts like a right-side magnet, pulling the text box to the right side of the screen
      "<div class='d-flex justify-content-end mb-3'>",
      
      # 'bg-primary' sets the background to your theme color (Yeti Blue); 'text-white' forces white lettering
      # 'shadow-sm' adds a tiny drop shadow; 'max-width: 75%' forces long sentences to wrap into a clean block
      "  <div class='bg-primary text-white p-2 px-3 rounded-3 shadow-sm' style='max-width: 75%; text-align: left;'>",
      "    ", input$user_prompt,
      "  </div>",
      "</div>"
    )
    
    # Build a Left-Aligned AI Bubble
    ai_bubble <- paste0(
      # 'justify-content-start' acts like a left-side magnet, pinning the text box to the left side of the screen
      "<div class='d-flex justify-content-start mb-3'>",
      
      # 'bg-light' colors the box light gray; 'text-dark' keeps text black; 'border' draws a clean separator line
      "  <div class='bg-light text-dark p-2 px-3 rounded-3 border shadow-sm' style='max-width: 75%; text-align: left;'>",
      "    ", new_response,
      "  </div>",
      "</div>"
    )
    
    # Combine both new elements and append them smoothly to your visual history string
    updated_history <- paste0(chat_log(), user_bubble, ai_bubble)
    
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
  
  
  # =========================================================================
  # CHAT LOG EXPORT HANDLER (USER CAN SAVE FILE TO LAPTOP)
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
        pending_disambiguation = cache$pending_disambiguation,
        cached_intent_phrase   = cache$cached_intent_phrase
      )
      
      # Pack it into a structured text file and download it
      jsonlite::write_json(session_snapshot, file, pretty = TRUE, auto_unbox = TRUE)
    }
  )
  
  # =========================================================================
  # CHAT LOG IMPORT HANDLER (USER CAN RELOAD PAST FILE)
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
    
    # 1. Update the reactiveVal to restore visual HTML history on screen
    chat_log(uploaded_snapshot$saved_chat_text)
    
    # 2. Re-inject all background tracking variables back into the cache
    cache$last_metadata_path      <- uploaded_snapshot$last_metadata_path
    cache$pending_disambiguation  <- uploaded_snapshot$pending_disambiguation
    cache$cached_intent_phrase    <- uploaded_snapshot$cached_intent_phrase
    
    showNotification("Chat session successfully restored!", type = "message")
  })
  
}

# Launch App ------------------------------------------------------------------

shinyApp(ui, server)
