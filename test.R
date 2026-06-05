library(shiny)
library(tidyverse)
library(reactable)
library(bslib)


metadata <- readRDS("metadata_inventory.rds")

# 2. USER INTERFACE
ui <- page_sidebar(
  title = "VCE Chatbot Data Availability Tracker",
  theme = bs_theme(version = 5, bootswatch = "minty"),
  
  sidebar = sidebar(
    title = "Filter Scope",
    
    selectInput("filter_category", "Select Topic Category:",
                choices = c("All Categories", unique(metadata$Category))),
    
    selectInput("filter_geo", "Select Geographic Level:",
                choices = c("All Levels", unique(metadata$Geographic_Level))),
    
    selectInput("filter_status", "Pipeline Project Status:",
                choices = c("All Statuses", unique(metadata$Status))),
    
    textInput("search_text", "Search Topics / Keywords:", placeholder = "e.g., suicide, lunch")
  ),
  
  card(
    card_header("Curated Data Inventory for VCE Agent Core Domains"),
    p("This matrix summarizes the public policy and health datasets identified during Week 2 data scoping. These structures will populate the upstream R-to-Python hybrid environment."),
    reactableOutput("inventory_table")
  )
)

# 3. REACTIVE BACKEND SERVER
server <- function(input, output, session) 
  
  filtered_data <- reactive({
    df <- metadata
    
    # Apply category dropdown filter
    if (input$filter_category != "All Categories") {
      df <- df %>% filter(Category == input$filter_category)
    }
    
    # Apply geographic level dropdown filter
    if (input$filter_geo != "All Levels") {
      df <- df %>% filter(Geographic_Level == input$filter_geo)
    }
    
    
    # Apply text keyword match across Topic and Organization columns
    if (input$search_text != "") {
      df <- df %>% filter(
        str_detect(tolower(Topic), tolower(input$search_text)) |
          str_detect(tolower(Organization), tolower(input$search_text))
      )
    }
    
    df
  })
  
 
# 4. RUN APPLICATION
shinyApp(ui, server)

