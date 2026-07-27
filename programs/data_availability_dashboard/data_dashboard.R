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

# Google Sheets Link
SECRET_GOOGLE_SHEET_URL <- "https://docs.google.com/spreadsheets/d/1n7NAei9LGKbbgVZYKWlY7CWOYWVFuXrz35i3F5APDkw/edit?gid=0#gid=0"

# =========================================================================
# USER INTERFACE
# =========================================================================
ui <- page_navbar(
  title = "DSPG 2026: VCE AI Tool",
  theme = bs_theme(version = 5, bootswatch = "minty"), 
  
  # -------------------------------------------------------------------------
  # TAB 1: Chatbot Showcase (Default Landing Page)
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Chatbot Showcase",
    # Wrap content in a container for centered, readable maximum widths
    div(
      class = "container mt-4",
      h2("VCE AI Assistant Prototype"),
      p("Below are static demonstrations of our interactive LLM chatbot. The tool utilizes DuckDB and localized vector retrieval to perform calculations and data routing."),
      hr(),
      
      # Placeholder for static screenshots
      # NOTE: Images must be placed inside a folder named 'www' in the same directory as this script.
      h4("Default Interface"),
      tags$img(src = "chatbot_main.png", style = "max-width: 100%; border: 1px solid #ccc; border-radius: 5px;", class = "mb-4"),
      
      h4("Query Execution & Thinking State"),
      p("We implemented a visual loading state to provide immediate UI feedback during complex LLM generation or DuckDB data aggregations."),
      tags$img(src = "chatbot_thinking.png", style = "max-width: 100%; border: 1px solid #ccc; border-radius: 5px;", class = "mb-4"),
      
      h4("Example Output & Citations"),
      tags$img(src = "chatbot_example.png", style = "max-width: 100%; border: 1px solid #ccc; border-radius: 5px;")
    )
  ),
  
  # -------------------------------------------------------------------------
  # TAB 2: Data Availability Dashboard (Your existing UI nested here)
  # -------------------------------------------------------------------------
  
  nav_panel(
    title = "Data Availability",
    div(
      class = "container-fluid mt4",
      h3("Data Availability Portal"),
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
# TAB 3: Overview
# -------------------------------------------------------------------------
nav_panel(
  title = "Overview",
  div(
    class = "container mt-4",
    h3("Project Overview"),
    p("Insert executive summary, goals, and methodologies here.")
  )
),

# -------------------------------------------------------------------------
# TAB 4: Literature Review & Repository
# -------------------------------------------------------------------------
nav_panel(
  title = "Literature Review",
  div(
    class = "container mt-4",
    h3("Literature Review"),
    p("Summary of the existing research and documentation."),
    hr(),
    h4("Source Code"),
    p("Review the complete architecture, routing logs, and data pipelines on our repository:"),
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
        category = "Unassigned", package_api = "N/A"
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
