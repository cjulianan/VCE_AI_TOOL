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
  
  # TEMPORARY, will probably change later but this is ok start
  
  # Doesn't work since too big
  # datasets <- list(
  #   ccd_directory = "data/outcome/Urban-Institute/2020-2024_ccd_directory.csv",
  #   ccd_enrollment = "data/outcome/Urban-Institute/2020-2024_ccd_directory.csv"
  # )
  
  # Works since this is a small dataset
  datasets <- list(
    adhd = "data/sources/Kaiser-Family-Foundation/Percent of Children (Ages 3 to 17) with ADHD.csv"
  )
  
  # Loop through datasets and convert them to json. Append each to combined_dataset
  combined_dataset <- ""
  for(dataset_name in names(datasets)) {
    file_path <- datasets[[dataset_name]]
    
    if(file.exists(file_path)) {
      df <- read.csv(file_path)
      df_json <- toJSON(df, pretty=TRUE)
      combined_dataset <- paste0(combined_dataset, "\n", df_json)
    }
  }
  
  # Tell system to only use dataset provided to respond
  system_prompt <- paste0("You are a data assistant. Only answer user prompts using the following dataset provided. Answer concisely and accurately based on the data and cite your answers. Do not answer user prompts that cannot be answered through using the following dataset. Following dataset: ", combined_dataset)
  
  
  
  
  # set up chatbot parameters
  chat_obj <- chat_openai_compatible(
    model = "gpt-oss-120b-thinking-high",
    base_url = "https://llm-api.arc.vt.edu/api/v1",
    credentials = function() Sys.getenv("VT_ARC_API_KEY"),
    system_prompt = system_prompt
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