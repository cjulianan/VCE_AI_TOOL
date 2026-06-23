
## HERE IS THE START OF OUR PROTOTYPE

library(ellmer)
library(bslib)
library(shiny)
library(DBI)
library(duckdb)
library(jsonlite)


################### GLOBAL INITIALIZATION ###################

# Initialize the persistent background DuckDB database engine (Runs once)
con <- dbConnect(duckdb())

onStop(function() {
  dbDisconnect(con, shutdown = TRUE)
})

# Here we load metadata JSON file right when the app loads. we make it an anctive readable R list object

app_metadata <- fromJSON("metadata.json", simplifyVector = FALSE)


################### THE RETRIEVAL ENGINE FUNCTION ###################

query_database_context <- function(filename, column, target_county) {
  
  if (!file.exists(filename)) {
    return("Error: The requested dataset file is missing from the directory path.")
  }
  
  dictionary_path <- file.path("data", "outcome", "census_dictionary.csv")
  
  # SQL JOIN TEMPLATE: Merges your raw table row with your local human translation key
  sql_query <- sprintf(
    "SELECT 
       data.county, 
       data.%s AS metric_value,
       dict.human_label
     FROM '%s' AS data
     LEFT JOIN '%s' AS dict
       ON dict.variable_code = '%s'
     WHERE lower(data.county) = '%s' 
     LIMIT 1",
    column, filename, dictionary_path, toupper(column), tolower(target_county)
  )
  
  result_df <- dbGetQuery(con, sql_query)
  
  if (nrow(result_df) == 0) {
    return(NULL)
  }
  
  # Fallback: If a dataset doesn't have a census lookup entry, use the raw column name 
  # Here we are adjusting for the non Census datasetr
  display_label <- result_df[1, "human_label"]
  if (is.na(display_label) || is.null(display_label)) {
    display_label <- column
  }
  
  context_sentence <- sprintf( 
    "Factual Context from file [%s]: In %s, the data for (%s) indicates a value of %s.",
    basename(filename), result_df[1, "county"], display_label, result_df[1, "metric_value"]
  ) 
  
  return(context_sentence)
}


################### THE COUNTY EXTRACTOR FUNCTION ###################

extract_county_name <- function(user_prompt, filename) {
  if (!file.exists(filename)) return(NULL)
  
  county_list_df <- dbGetQuery(con, sprintf("SELECT DISTINCT county FROM '%s'", filename))
  raw_counties <- county_list_df$county
  
  clean_prompt <- tolower(user_prompt)
  lower_counties <- tolower(raw_counties)
  
  match_index <- which(sapply(lower_counties, function(co) grepl(co, clean_prompt)))
  
  if (length(match_index) > 0) {
    return(raw_counties[match_index[1]])
  }
  return(NULL)
}


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
    
    # ---------------------------------------------------------------------
    # PIPELINE INTEGRATION STEP: HARDCODED ROUTING FOR TODAY'S TEST
    # ---------------------------------------------------------------------
    # Once we map out our full JSON loop later this week, this part will be automatic.
    # For today's test, we will point it directly to your master census file.
    test_file <- "data/outcome/American-Community-Survey/2020-2024_acs_master_county.csv.csv"
    test_column <- "B14005" # Adjust this to a column you know exists in your file!
    
    # Step A: Run your county text scanner on the user's prompt
    matched_county <- extract_county_name(input$user_prompt, test_file)
    
    # Initialize an empty context string
    data_context <- ""
    
    # Step B: If the scanner finds a county, use DuckDB to grab the facts
    if (!is.null(matched_county)) {
      data_context <- query_database_context(test_file, test_column, matched_county)
    }
    
    # Step C: Combine the database fact sheet with the user's question
    # This forces the LLM to look at your data instead of guessing.
    final_prompt <- sprintf(
      "You are a helpful policy assistant. Use the following data context to answer the user's question accurately. If the context is empty, answer normally.\n\nContext: %s\n\nUser Question: %s",
      data_context,
      input$user_prompt
    )
    
    new_response <- chat_obj$chat(final_prompt)
    
    updated_history <- paste0(
      chat_log(), "<br>",
      "<strong>User:</strong> ", input$user_prompt, "<br>",
      "<strong>AI:</strong> <i>", new_response, "</i><br>"
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
