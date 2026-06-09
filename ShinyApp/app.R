#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)

# Define UI for application that draws a histogram
ui <- navbarPage (
  "DSPG",
  tabPanel("Overview", 
           h3("VCE AI TOOL"),
           fluidRow(
             column(4,p("idk")),
             column(4,p("idk2")),
             column(4,p("idk3"))
             # add later when have img: column(1,p("idk4"), img(src="", width="100%"))
           )
           ),
  
  tabPanel("Literature Review", 
           p("Placeholder")
           )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

}

# Run the application 
shinyApp(ui = ui, server = server)
