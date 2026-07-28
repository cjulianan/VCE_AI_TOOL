# =========================================================================
# DSPG 2026: Data Availability Dashboard
# =========================================================================
library(shiny)
library(tidyverse)
library(reactable)
library(googlesheets4)
library(bslib)


# 1. Authorizes Google Sheets to read public links without a login prompt
gs4_deauth()

# Google Sheets Link for Data Availability Dashboard
SECRET_GOOGLE_SHEET_URL <- "https://docs.google.com/spreadsheets/d/1n7NAei9LGKbbgVZYKWlY7CWOYWVFuXrz35i3F5APDkw/edit?gid=0#gid=0"

# =========================================================================
# USER INTERFACE
# =========================================================================
ui <- page_navbar(
  title = "DSPG 2026: VCE AI Tool",
  theme = bs_theme(version = 5, bootswatch = "morph"), 
  
  # -------------------------------------------------------------------------
  # TAB 1: Chatbot Showcase (Default Landing Page)
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Chatbot Showcase",
    # Wrap content in a container for centered, readable maximum widths
    div(
      class = "container mt-4",
      
      div(
        class = "bg-dark text-white p-3 rounded mb-3 shadow-sm",
        h2("VCE AI Assistant Prototype", class = "m-0")
      ),
      
      p("Below are static demonstrations of our interactive LLM chatbot. The tool uses DuckDB and localized vector retrieval to perform calculations and route to the right datasets."),
      hr(),
      
      # NOTE: Images must be placed inside folder 'www' in the same directory as this script.
      div(
        class = "bg-dark text-white p-3 rounded mb-3 shadow-sm",
        h4("Default Interface of the App", class = "m-0")
      ),
      
      tags$img(src = "chatbot_pic_1.png", style = "max-width: 85%; border: 3px solid #2c3e50; border-radius: 8px;", class = "mb-4"),
      
      h4("Features"),
      p("Here are some of the features our chatbot currently support:"),
      tags$img(src = "chatbot_pic_3.png", style = "max-width: 85%; border: 3px solid #2c3e50; border-radius: 8px;", class = "mb-2"),
      h5("Save Chat Session:"),
      p("You can export your chat session into a small JSON file for continuing it later."),
      h5("Upload Previous Chat Session"),
      p("Upload the same chat session at a later time to see what you were working on & easily get back into it."),
      
      
      h4("Example Questions & Answers with Citations"),
      p("Here are some examples of questions one could ask, with citations being provided for where each dataset that the LLM used
        to answer the question comes from."),
      tags$img(src = "chatbot_pic_2.png", style = "max-width: 85%; border: 3px solid #2c3e50; border-radius: 8px;", class = "mb-3"),
      h6("Example 1: Chickenpox disease from the VDH PUD Reportable Diseases Dataset - you can follow up with a new county, too.")
    )
  ),
  
  # -------------------------------------------------------------------------
  # TAB 2: Data Availability Dashboard 
  # -------------------------------------------------------------------------
  
  nav_panel(
    title = "Data Availability",
    div(
      class = "container-fluid mt-4",
      div(
        class = "bg-dark text-white p-3 rounded mb-3 shadow-sm",
        h3("Data Availability Portal")
      ),
      
      p("Search and filter for variables available in our database repository"),
      hr(),
      
      sidebarLayout(
        sidebarPanel(
          width = 3,
          selectInput("cat_filter", "Filter by Sector Domain:", choices = c("All Categories")),
          hr(),
          helpText("💡 Type any variable into the global search bar (like insurance or education) or the 'Variables' column filter to instantly find the containing cluster file")
        ),
        
        mainPanel(
          width = 9,
          reactableOutput("master_registry_table")
        )
      )
    )
  ),
  
  # -------------------------------------------------------------------------
  # TAB 3: Overview (Image of US & Description of Project)
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Overview",
    div(
      class = "container mt-4",
      div(
        class = "bg-dark text-white p-3 rounded mb-3",
        h3("Project Overview")
      ),
      
      p("Pic of me and Sherlock, motivation for the project, goals, and what we managed to do with the project.")
    )
  ),
  
  # -------------------------------------------------------------------------
  # TAB 4: Literature Review & Github Repository Link
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Literature Review & Github Repository",
    div(
      class = "container mt-4",
      div(
        class = "bg-dark text-white p-3 rounded mb-3",
        h3("Literature Review")
      ),
      p("Summary of the existing research and documentation."),
      
      
      h6("📚 Source: A Survey on Knowledge-Oriented Retrieval-Augmented Generation, ",
         tags$a(
           href = "https://arxiv.org/pdf/2503.10677",
           target = "_blank",
           rel = "noopener noreferrer",
           "PDF Source"
         )
      )  
      ,
      p("RAG has been used in multiple fields, such as pulling information from financial, legal, and industrial texts (Section 8.2). Denoising techniques of dataset, such as confidence scoring to reduce hallucinations (Section 5.7). 
       Agentic RAG, most relevant to this project, has limitations such as error propagations (tasks requiring many steps can easily lead to errors), cannot interpret data very deeply (explaining why rather than just giving facts), and is not as flexible at retrieval planning (may waste resources unnecessarily calling API when it can just reference data it found previously) (Section 9.4)."),
      hr(),
      h4("Source Code"),
      p("Review the complete architecture and data pipelines on our repository:"),
      tags$a(
        href = "https://github.com/cjulianan/VCE_AI_TOOL", 
        target = "_blank", 
        rel = "noopener noreferrer", 
        class = "btn btn-primary",
        icon("github"), "View on GitHub"
      )
    )
  )
)

# =========================================================================
# SERVER
# =========================================================================
server <- function(input, output, session) {
  
  # Reactive data pull from Google Sheets
  raw_registry <- reactive({
    req(SECRET_GOOGLE_SHEET_URL)
    
    read_sheet(SECRET_GOOGLE_SHEET_URL) %>%
      # Standardize column headers to clean snake_case to match R processing requirements
      rename_with(~str_to_lower(.) %>% str_replace_all("[^a-z0-9]+", "_")) %>%
      # Ensure everything reads as clean text characters
      mutate(across(everything(), as.character)) %>%
      # Safety Net: Replace missing values with readable placeholders
      replace_na(list(
        dataset_name = "Unlabeled", 
        variable = "", label = "No description provided", 
        category = "Unassigned", package_api = "N/A",
        codebook_url = "N/A"
      ))
  })
  
  # Update sidebars based on sheet data contents
  observe({
    df <- raw_registry()
    updateSelectInput(session, "cat_filter", choices = c("All Categories", unique(df$category)))
  })
  
  # Build and render the interactive table
  output$master_registry_table <- renderReactable({
    df <- raw_registry()
    
    # Apply filtering selection for Categories
    if (input$cat_filter != "All Categories") {
      df <- df %>% filter(category == input$cat_filter)
    }
    
    reactable(
      df,
      filterable = TRUE,   
      searchable = TRUE,   
      striped = TRUE,      
      highlight = TRUE,    
      bordered = TRUE,     
      pageSizeOptions = c(10, 25, 50, 100), 
      defaultPageSize = 25,
      
      # New addition, injects a professional theme to match Bootswatch "Minty"
      theme = reactableTheme(
        headerStyle = list(
          background = "#2c3e50",        # Crisp dark slate header background
          color = "#ffffff",             # Clean white text for readability
          fontWeight = "bold",
          borderBottom = "3px solid #78c2ad" # Mint green accent border under headers
        ),
        rowStripedStyle = list(background = "#f8f9fa"),
        rowHighlightStyle = list(background = "#e8f4f1") # Subtle mint glow on hover
      ),
      
      # Maps the spreadsheet columns to capitalized UI headers
      columns = list(
        dataset_name = colDef(name = "Source Dataset"),
        file_name = colDef(name = "File Name", style = list(fontFamily = "monospace")),
        variable = colDef(name = "Variables / Parent Codes", minWidth = 150, style = list(fontWeight = "bold", color = "#2c3e50")),
        label = colDef(name = "Plain Description", minWidth = 250), 
        category = colDef(name = "Domain"),                                   
        years_available = colDef(name = "Years Covered"),
        geographic_level = colDef(name = "Geography"),
        package_api = colDef(name = "Package / API Used", style = list(fontFamily = "monospace")),
        codebook_url = colDef( # Builds HTML Link
          name = "Codebook Reference",
          html = TRUE,
          cell = function(value) {
            # Check if a valid URL string exists before building the HTML 
            if (!is.na(value) && value != "" && value != "N/A") {
              paste0("<a href='", value, "' target='_blank' rel='noopener noreferrer'>View Link</a>")
            } else {
              "N/A"
            }
          }
          
        )
      )
    )
  })
}

shinyApp(ui, server)