# Got querying for specific metadata json for the dataset related to user prompt to work. Still can't really ask questions since it only retrieves metadata and not csv. Also have not implemented duckdb for sql querying yet for this script but have other logic working in programs/chatbot/test.R script.

# used for now since main file paths for metadata and csvs are from outside of where this script is folder location wise
if (basename(getwd()) == "chatbot") {
  PATH_PREFIX <- "../../"
} else {
  PATH_PREFIX <- ""
}

con <- dbConnect(duckdb())
onStop(function() { dbDisconnect(con, shutdown = TRUE) })

# function for going through master_registry.json to loop through and find matching keywords to the user prompt.
# used later to get path for actual metadata json path for related dataset
route_user_prompt <- function(user_prompt, registry_path = "data/outcome/master_registry.json") {
  actual_path <- paste0(PATH_PREFIX, registry_path)
  if (!file.exists(actual_path)) return(NULL)
  
  registry <- fromJSON(actual_path, simplifyVector = FALSE)
  clean_prompt <- tolower(user_prompt)
  
  for (dataset in registry$routing_registry) {
    keywords_vec <- tolower(unlist(dataset$keywords))
    for (keyword in keywords_vec) {
      if (grepl(keyword, clean_prompt, fixed = TRUE)) return(dataset)
    }
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
    model = "gpt-oss-120b-thinking-high",
    base_url = "https://llm-api.arc.vt.edu/api/v1",
    credentials = function() Sys.getenv("ARC_API_KEY"),
    system_prompt = "You are a helpful data assistant. Use the data provided in final prompt to answer accurately. Do not use any outside information. Keep answers short and factual. Cite where you got information from."
  )
  
  # keep record of chat log so new responses aren't overwritten
  chat_log <- reactiveVal("Chat Started: <br>")
  
  # only update chat box if user hits submit button and user has something in prompt input box
  observeEvent(input$submit_button, {
    req(input$user_prompt) 
    
    # call function for matching the correct route from master registry
    matched_route <- route_user_prompt(input$user_prompt, "data/outcome/master_registry.json")
    
    # pull out the actual file path for the related metadata json
    metadata_file_path <- "No matching metadata found."
    if (!is.null(matched_route)) {
      metadata_file_path <- matched_route$metadata_path
    }
    
    # put metadata path and user question into a final prompt to be given to chatbot
    final_prompt <- sprintf(
      "Metadata Path: %s\n\nUser Question: %s", 
      metadata_file_path, 
      input$user_prompt
    )
    
    new_response <- chat_obj$chat(final_prompt)
    
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