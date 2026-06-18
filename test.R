
## HERE IS THE START OF OUR PROTOTYPE

library(ellmer)
library(bslib)
library(shiny)

# =========================================================================
# AUTOMATED DATA INGESTION LAYER
# =========================================================================

######### Function A: The Automated GPS Map

## COMMENTED EVERYTHING UNDER HERE


# # Why: This runs once when the app boots. It maps out where every file lives 
# # in 'data/outcome/' so you never have to hardcode paths when adding files (like if one of us updates a dataset in our Github).
# ingest_all_metadata <- function() {
#   base_folder <- file.path("data", "outcome")
#   
#   if (!dir.exists(base_folder)) {
#     warning("The directory 'data/outcome/' was not detected.")
#     return(NULL)
#   }
#   
#   # 1. THE CRAWLER STEP: Scan all nested subfolders automatically
#   # recursive = TRUE: Force R to jump into every subfolder depth
#   # pattern = "\\.csv$": Only pick up clean CSV files, ignore other junk files
#   # full.names = TRUE: Keep the entire usable relative path strin
#   all_file_paths <- list.files(
#     path = base_folder, 
#     pattern = "\\.csv$", 
#     recursive = TRUE, 
#     full.names = TRUE
#   )
#   
#   ## 2. Converts file paths into a searchable dictionary frame
#   # This matches file names to their physical home paths automatically
#   registry <- data.frame(
#     file_name = basename(all_file_paths), # ex. "census_nass_crops.csv"
#     full_path = all_file_paths,
#     stringsAsFactors = FALSE
#   )
#   
#   return(registry) # now we have the live directory map of all available datasets
# }
# 
# # Run the GPS map once globally
# cohort_file_map <- ingest_all_metadata()
# 
# 
# ######### Function B: The On-Demand Data Grabber
# 
# # Why: This is the function your retrieval layer will call. It takes a file 
# # name (like "census_nass_crops.csv"), looks up its full path from the GPS map,
# # and reads the actual table rows into active memory instantly.
# get_target_data <- function(target_file_name, path_map_df) {
#   
#   # Filter our GPS map to find the exact matching row for our target filename
#   matched_row <- path_map_df[path_map_df$file_name == target_file_name, ]
#   
#   # Safety check: If the file name doesn't exist in the map, exit safely
#   if (nrow(matched_row) == 0) {
#     return(NULL)
#   }
#   
#   # Extract the raw text path string from our dataframe row
#   exact_file_path <- matched_row$full_path
#   
#   # READ THE ACTUAL DATA ROWS HERE! 
#   # This makes the data active and queryable for your retrieval layer.
#   actual_data <- read.csv(exact_file_path, stringsAsFactors = FALSE)
#   
#   return(actual_data)
#}

# UI ----------------------------------------------------------------------

ui <- fluidPage(
  titlePanel("Chatbot Prototype"),
  
  textInput("user_prompt", "Please input your prompt: ", placeholder = "Ask AI"),
  actionButton("submit_button", "Submit prompt"),
  
  hr(),
  h4("AI Response:"),
  
  # used to style response box
  card(
    card_body(
      uiOutput("ai_response"),
      style = "max-height: 400px; overflow-y: auto;"
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
  
  # only update chat box if user hits submit button and user has something in prompt input box
  observeEvent(input$submit_button, {
    req(input$user_prompt) 
    
    new_response <- chat_obj$chat(input$user_prompt)
    
    updated_history <- paste0(
      chat_log(), "<br>",
      "<strong>User:</strong> ", input$user_prompt, "<br>",
      "<strong>AI:</strong> ", new_response, "<br>"
    )
    
    # update chat log to include new prompt and response
    chat_log(updated_history)
    
    # resets the prompt input box to be empty after prompt has been entered and submitted
    updateTextInput(session, "user_prompt", value = "")
  })
  
  # render the new chat along with all the previous dialogues coming before it
  output$ai_response <- renderUI({
    HTML(chat_log())
  })
}


# Launch App ------------------------------------------------------------------

shinyApp(ui, server)
