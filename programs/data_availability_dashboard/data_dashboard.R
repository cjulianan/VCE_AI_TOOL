# =========================================================================
# DSPG 2026: Data Availability Dashboard
# =========================================================================
library(shiny)
library(tidyverse)
library(reactable)
library(googlesheets4)
library(bslib)


## Hyperlinks don't work yet, I'm gonna try to fix that. They are available in the Google Spreadsheet though
# 1. Authorizes Google Sheets to read public links without a login prompt
gs4_deauth()

# Google Sheets Link
SECRET_GOOGLE_SHEET_URL <- "https://docs.google.com/spreadsheets/d/1n7NAei9LGKbbgVZYKWlY7CWOYWVFuXrz35i3F5APDkw/edit?gid=0#gid=0"

# =========================================================================
# USER INTERFACE
# =========================================================================
ui <- fluidPage(
  theme = bs_theme(version = 5, bootswatch = "minty"), 
  
  titlePanel("DSPG 2026: VCE Team Data Availability Portal"),
  p("Search and filter for clean variables available in our shared database repository"),
  hr(),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectInput("team_filter", "Filter by Research Team:", choices = c("All Teams")),
      selectInput("cat_filter", "Filter by Sector Domain:", choices = c("All Categories")),
      hr(),
      helpText("💡 Type any variable into the global search bar (like insurance) or the 'Variables' column filter to instantly find the containing cluster file")
    ),
    
    mainPanel(
      width = 9,
      reactableOutput("master_registry_table")
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
        team = "Unknown Team", dataset_name = "Unlabeled", 
        variable = "", label = "No description provided", 
        category = "Unassigned", package_api = "N/A"
      ))
  })
  
  # Update sidebars based on sheet data contents
  observe({
    df <- raw_registry()
    updateSelectInput(session, "team_filter", choices = c("All Teams", unique(df$team)))
    updateSelectInput(session, "cat_filter", choices = c("All Categories", unique(df$category)))
  })
  
  # Build and render the interactive table
  output$master_registry_table <- renderReactable({
    df <- raw_registry()
    
    # Apply filtering selections
    if (input$team_filter != "All Teams") {
      df <- df %>% filter(team == input$team_filter)
    }
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
        team = colDef(name = "Research Team", minWidth = 100),
        dataset_name = colDef(name = "Source Dataset"),
        file_name = colDef(name = "File Name", style = list(fontFamily = "monospace")),
        variable = colDef(name = "Variables / Parent Codes", minWidth = 150, style = list(fontWeight = "bold", color = "#2c3e50")),
        label = colDef(name = "Plain Description", minWidth = 250, html = TRUE), # html = TRUE preserves any embedded hyperlinks (this doesn't work, will fix it
        category = colDef(name = "Domain"),                                     # so that links are clickable in R shinny app
        years_available = colDef(name = "Years Covered"),
        geographic_level = colDef(name = "Geography"),
        package_api = colDef(name = "Package / API Used", style = list(fontFamily = "monospace"))
      )
    )
  })
}

shinyApp(ui, server)
