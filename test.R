
## HERE IS THE START OF OUR PROTOTYPE

library(ellmer)
library(bslib)
library(shiny)
library(DBI)
library(duckdb)


library(shiny)
library(bslib)
library(ellmer)
library(DBI)
library(duckdb)

################### GLOBAL DATABASE CONNECTION 

# Initialize the DuckDB driver and connect to an in-memory database instance.
# This tells R to run the serverless engine directly in the app's RAM.
con <- dbConnect(duckdb())

# Shiny Habit: Ensures that when the Shiny application completely shuts down, 
# it cleanly releases the database lock and frees up system resources.
onStop(function() {
  dbDisconnect(con, shutdown = TRUE)
})


################### THE RETRIEVAL ENGINE FUNCTION 

# Why: We wrap this logic inside a function container so it doesn't run automatically 
# on startup. It sits on standby until we pass it the target file and county variables
query_database_context <- function(filename, column, target_county) {
  
  # Safety Check: If the file does not exist locally yet, we exit
  if (!file.exists(filename)) {
    return("Error: The requested dataset file is missing from the directory path.")
  }
  
  # this is our template for how the duckdb sql query is going to search through our dataset
  sql_query <- sprintf(
    "SELECT county, %s FROM '%s' WHERE lower(county) = '%s' LIMIT 1",
    column, filename, tolower(target_county)
  )
  
  ############ EXECUTING THE DUCKDB QUERY
  
  # DuckDB opens the file, grabs the exact column and row cells, and returns 
  # a 1-row data frame which we store in the variable 'result_df'.
  result_df <- dbGetQuery(con, sql_query)
  
  # Safety Check: If a user types a typo or a county that doesn't exist in 
  # that specific table, DuckDB will return 0 rows. This blocks R from crashing.
  if (nrow(result_df) == 0) {
    return(NULL)
  }
  
  ############ ACTUAL ANSWER GENERATION/CONSTRUCTION
  
  # Transforms table cells into clean, plain text factual sentences 
  context_sentence <- sprintf( 
    "Factual Context from file [%s]: In %s, the value for %s is %s.",
    basename(filename), result_df[1, "county"], column, result_df[1, column]
  ) 
  
  return(context_sentence)
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
    
    new_response <- chat_obj$chat(input$user_prompt)
    
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
