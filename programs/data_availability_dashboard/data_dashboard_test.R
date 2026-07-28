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
# BSLIB CUSTOM THEME (VCE / Virginia Tech Inspired)
# =========================================================================
# Replaces the stark white background with a soft gray, uses VT Maroon as the 
# primary color, and VT Orange as the secondary accent color.
vce_theme <- bs_theme(
  version = 5,
  bg = "#F4F6F9",        # Soft light gray background (easier on the eyes than stark white)
  fg = "#2C3E50",        # Dark slate for readable text
  primary = "#861F41",   # VT Chicago Maroon
  secondary = "#E87722", # VT Burnt Orange
  base_font = font_google("Inter"),
  heading_font = font_google("Montserrat")
)

# =========================================================================
# USER INTERFACE
# =========================================================================
ui <- page_navbar(
  title = "DSPG 2026: VCE AI Tool",
  theme = vce_theme,
  fillable = FALSE, # Allows page to scroll naturally rather than stretching
  
  # -------------------------------------------------------------------------
  # TAB 1: Chatbot Showcase (Default Landing Page)
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Chatbot Showcase",
    div(
      class = "container mt-4",
      
      # Using bslib::card() for professional, modern containers with drop shadows
      card(
        class = "shadow-sm mb-4",
        card_header(
          class = "bg-primary text-white",
          h3("VCE AI Assistant Prototype", class = "m-0")
        ),
        card_body(
          p(class = "lead", "Below are static demonstrations of our interactive LLM chatbot. The tool uses DuckDB and localized vector retrieval to perform calculations and route to the right datasets.")
        )
      ),
      
      card(
        class = "shadow-sm mb-4",
        card_header(
          class = "bg-primary text-white",
          h4("Default Interface of the App", class = "m-1")
        ),
        card_body(
          tags$img(src = "chatbot_pic_1.png", class = "img-fluid rounded border mb-4", style = "max-width: 90%;"),
          card_header(
            class = "bg-primary text-white",
            h4("Features", class = "m-1")
            ),
            
          p("Here are some of the features our chatbot currently supports:"),
          tags$img(src = "chatbot_pic_3.png", class = "img-fluid rounded border mb-4", style = "max-width: 90%;"),
          
          layout_columns(
            col_widths = c(6, 6),
            div(
              h5(icon("download"), " Save Chat Session", class = "text-secondary"),
              p("You can export your chat session into a small JSON file for continuing it later.")
            ),
            div(
              h5(icon("upload"), " Upload Previous Chat", class = "text-secondary"),
              p("Upload the same chat session at a later time to see what you were working on & easily get back into it.")
            )
          )
        )
      ),
      
      card(
        class = "shadow-sm mb-4",
        card_header(
          class = "bg-primary text-white",
          h4("Example Questions & Answers with Citations", class = "m-1")
        ),
        card_body(
          p("Here are some examples of questions one could ask, with citations being provided for where each dataset that the LLM used to answer the question comes from."),
          tags$img(src = "chatbot_pic_2.png", class = "img-fluid rounded border mb-2", style = "max-width: 90%;"),
          p(strong("Example 1:"), " Chickenpox disease from the VDH PUD Reportable Diseases Dataset - you can follow up with a new county, too.")
        ),
        card_header(
          class = "bg-primary text-white",
          h5("Want to see detailed instructions for how to use the Chatbot?", class = "m-1")),
        card_body(
          h6(
            "📄 Here is a link to our ",
            tags$a(
              href = "https://github.com/cjulianan/VCE_AI_TOOL/blob/main/README.md#-user-guide",
              target = "_blank",
              rel = "noopener noreferrer",
              class = "text-secondary", # VT Orange link
              "User Guide"

          )
        )
          
          
        )
      )
    )
  ),
  
  # -------------------------------------------------------------------------
  # TAB 2: Data Availability Dashboard 
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Data Availability",
    div(
      class = "container-fluid mt-4",
      
      card(
        class = "shadow-sm",
        card_header(
          class = "bg-primary text-white",
          h3("Data Availability Portal", class = "m-1")
        ),
        card_body(
          p(class = "text-muted", "Search and filter for variables available in our database repository."),
          
          # Modern bslib layout for sidebars
          layout_sidebar(
            sidebar = sidebar(
              width = 300,
              title = "Dashboard Filters",
              bg = "#ffffff", # Clean white sidebar against the off-white background
              selectInput("cat_filter", "Filter by Sector Domain:", choices = c("All Categories")),
              hr(),
              helpText("💡 Type any variable into the global search bar (like insurance or education) or the 'Variables' column filter to instantly find the containing cluster file.")
            ),
            
            reactableOutput("master_registry_table")
          )
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
      card(
        class = "shadow-sm",
        card_header(
          class = "bg-primary text-white",
          h3("Project Overview", class = "m-1")
        ),
        card_body(
          p("Pic of me and Sherlock, motivation for the project, goals, and what we managed to do with the project."),
          card_header(
            class = "bg-primary text-white",
            h6("Nebiyou Mengistu & Sherlock Chen (VCE AI Tool Team)", class = "m-2")
          ),
          tags$img(src = "nebiyou_sherlock.jpg", class = "img-fluid rounded border mb-3", style = "max-width: 90%;")
        )
      )
    )
  ),
  
  # -------------------------------------------------------------------------
  # TAB 4: Literature Review & Github Repository Link
  # -------------------------------------------------------------------------
  nav_panel(
    title = "Literature Review & Repository",
    div(
      class = "container mt-4",
      card(
        class = "shadow-sm mb-4",
        card_header(
          class = "bg-primary text-white",
          h3("Literature Review", class = "m-1")
        ),
        card_body(
          p(class = "lead", "Summary of the existing research and documentation."),
          
          h6(
            "📚 Source: A Survey on Knowledge-Oriented Retrieval-Augmented Generation, ",
            tags$a(
              href = "https://arxiv.org/pdf/2503.10677",
              target = "_blank",
              rel = "noopener noreferrer",
              class = "text-secondary", # VT Orange link
              "PDF Source"
            )
          ),
          
          p("RAG has been used in multiple fields, such as pulling information from financial, legal, and industrial texts (Section 8.2). Denoising techniques of dataset, such as confidence scoring to reduce hallucinations (Section 5.7).,
          Agentic RAG, most relevant to this project, has limitations such as error propagations (tasks requiring many steps can easily lead to errors), cannot interpret data very deeply (explaining why rather than just giving facts), 
            and is not as flexible at retrieval planning (may waste resources unnecessarily calling API when it can just reference data it found previously) (Section 9.4).")
        )
      ),
      
      card(
        class = "shadow-sm",
        card_header(
          class = "bg-primary text-white",
          h4("Source Code", class = "m-1")
        ),
        card_body(
          p("Review the complete architecture and data pipelines on our repository:"),
          tags$a(
            href = "https://github.com/cjulianan/VCE_AI_TOOL", 
            target = "_blank", 
            rel = "noopener noreferrer", 
            # btn-secondary triggers the VT Orange accent color
            class = "btn btn-secondary", 
            icon("github"), " View on GitHub"
          )
        )
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
      rename_with(~str_to_lower(.) %>% str_replace_all("[^a-z0-9]+", "_")) %>%
      mutate(across(everything(), as.character)) %>%
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
      
      # Themed to match the VT Custom Theme
      theme = reactableTheme(
        headerStyle = list(
          background = "#861F41",            # VT Maroon Header
          color = "#ffffff",                 # White text
          fontWeight = "bold",
          borderBottom = "4px solid #E87722" # VT Orange Accent Line under Header
        ),
        rowStripedStyle = list(background = "#ffffff"), # Keep rows white so they pop against the gray app background
        rowHighlightStyle = list(background = "#fce8e3") # Subtle soft orange glow on hover
      ),
      
      columns = list(
        dataset_name = colDef(name = "Source Dataset"),
        file_name = colDef(name = "File Name", style = list(fontFamily = "monospace", fontSize = "0.9em")),
        variable = colDef(name = "Variables / Parent Codes", minWidth = 150, style = list(fontWeight = "bold", color = "#861F41")),
        label = colDef(name = "Plain Description", minWidth = 250), 
        category = colDef(name = "Domain"),                                   
        years_available = colDef(name = "Years Covered"),
        geographic_level = colDef(name = "Geography"),
        package_api = colDef(name = "Package / API Used", style = list(fontFamily = "monospace")),
        codebook_url = colDef(
          name = "Codebook Reference",
          html = TRUE,
          cell = function(value) {
            if (!is.na(value) && value != "" && value != "N/A") {
              paste0("<a href='", value, "' target='_blank' rel='noopener noreferrer' style='color: #E87722; font-weight: bold;'>View Link</a>")
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