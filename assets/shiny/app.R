library(shiny)
library(slickR)
library(tidyverse)
library(radarchart)
library(glue)
library(lubridate)
library(shinycssloaders)
library(shinythemes)

data <- read_csv("aradeepopsis_traits.csv")
imagenames <- data %>% select(file)

traitcount <- ncol(data) - 2 #filename and extension don't count
imagecount <- nrow(data)

# Define UI
ui <- navbarPage(title="araDeepopsis", theme = shinytheme("flatly"),
		tabPanel("Rosette Carousel",
				sliderInput("chunk", label = "Select chunk:", min = 1, max = ceiling(imagecount/60), value = 1, width = '100%', step = 1),
				slickROutput("slickr",width='100%',height='400px') %>% withSpinner()
		),
		tabPanel("Rosette Explorer",
				sidebarPanel(
					selectizeInput("explorer_files",label="Select Image:", choices=NULL)
				),
				mainPanel(
					tabsetPanel(id='tabset1',
								tabPanel("Overlay",value=0,imageOutput("overlay")),
								tabPanel("Mask",value=0,imageOutput("mask")),
								tabPanel("Rosette",value=0,imageOutput("rosette")),
								tabPanel("Leaf Classification",value=0,chartJSRadarOutput("radar", height = "200"))
					),
				),
		),
		tabPanel("Rosette Statistics",
				sidebarPanel(
					verbatimTextOutput("info"),
					conditionalPanel(
						condition="input.tabset2 > 0",
						selectizeInput("statistics_traits","Select Trait:", choices = colnames(data %>% select(-file,-format)), selected = "rosette"),
						conditionalPanel(
						condition="input.tabset2 == 2",
						selectizeInput("statistics_files",label="Select Image:", choices=NULL)
						)
					)
				),
				mainPanel(
					tabsetPanel(id='tabset2',
								tabPanel("Trait Histogram",value=1,plotOutput("histograms")),
								tabPanel("Trait Jitterplot",value=2,plotOutput("jitter"))
					)
				)
		),
		tabPanel("Rosette Experiment",
				sidebarPanel(
					fileInput("metadata",label = "Select file"),
					tableOutput("meta"),
					varSelectInput("file","Select column containing the filename", data = NULL),
					varSelectInput("date","Select column containing the date", data = NULL),
					varSelectInput("id","Select column containing grouping variable", data = NULL),
					actionButton("mergedat", "Merge data"),
					selectizeInput("exp_traits","Select Trait:", choices = colnames(data %>% select(-file,-format)), selected = "rosette")
				),
				mainPanel(
					tabsetPanel(id='tabset3',
								tabPanel("Traits over time",value=0,plotOutput("timeline"))
					)
				)
		)
)

server <- function(input, output, session) {
    #for large datasets it helps with performance if selection lists are done on the server-side
    updateSelectizeInput(session, "statistics_files", choices = c(imagenames), server = TRUE)
    updateSelectizeInput(session, "explorer_files", choices = c(imagenames), server = TRUE)
    
    output$mask <- renderImage({
        list(src = glue("diagnostics/single_pot/mask/{input$explorer_files}.png"),width=400,height=400)
    }, deleteFile = FALSE)
    output$rosette <- renderImage({
        list(src = glue("diagnostics/single_pot/crop/{input$explorer_files}.jpeg"),width=400,height=400)
    }, deleteFile = FALSE)
    output$overlay <- renderImage({
        list(src = glue("diagnostics/single_pot/overlay/{input$explorer_files}.jpeg"),width=400,height=400)
    }, deleteFile = FALSE)
    output$radar = renderChartJSRadar({
        data %>%
            filter(file == input$explorer_files) %>%
            select(one_of(c("rosette","anthocyanin","senescent"))) %>% 
            pivot_longer(everything(),names_to = "Label") %>% 
            mutate(value=value/sum(value)*100) %>% 
            chartJSRadar(.,maxScale = 100,scaleStartValue = 0,scaleStepWidth = 25,showLegend = F)
        
    })
    output$histograms = renderPlot(width=400,{
        data %>%
            select(file,input$statistics_traits) %>%
            ggplot(aes_string(input$statistics_traits)) +
            geom_histogram(bins = 100) +
            theme_bw()
    })
    output$jitter = renderPlot(width=400,{
        data %>%
            select(file,input$statistics_traits) %>%
            ggplot(aes_string(x=as.factor(input$statistics_traits),y=input$statistics_traits)) +
            geom_jitter(colour="black",alpha=0.3,size=5) +
            geom_jitter(data = {. %>% filter(file==input$statistics_files)}, colour="red", size=5) +
            xlab(element_blank()) +
            ylab("measurement") +
            theme_bw()
    })
    output$meta = renderTable({
        filedata() %>% head()
    })
    
    filedata <- eventReactive (input$metadata,{
        metafile <- input$metadata
        req(metafile)
        table <- read_csv(metafile$datapath)
        columns = colnames(table)
        updateselectizeInput(session, "file", choices = columns)
        #TODO handle different date formats
        updateselectizeInput(session, "date", choices = columns)
        updateselectizeInput(session, "id", choices = columns)
        table
    })
    
    joined <- eventReactive(input$mergedat,{
        data %>%
            rename(!!input$file := file) %>%
            left_join(.,filedata(),by=as.character(input$file)) %>%
            mutate(date = !!input$date %>% mdy(.,truncated = 1)) %>%
            group_by(!!input$id)
    })
    
    output$merged = renderTable({
        joined() %>% head()
    })
    output$timeline = renderPlot({
        joined() %>% ggplot(aes_string(x='date',y=input$exp_traits,colour=quo(as.factor(!!input$id)))) + #this seems wrong but works
            stat_summary() +
            theme_bw()
    })
    
    output$info = renderText({
        glue("Measured {traitcount} traits across {imagecount} rosettes")
    })
    output$slickr <- renderSlickR({
        
        # split the filenames into chunks of 60, corresponding to 10 pages per chunk
        # this drastically improves page loading time
        chunks <- if (imagecount > 60) split(imagenames$file, ceiling(seq_along(imagenames$file)/60)) else split(imagenames$file, 1)
        
        opts <- settings(slidesToShow = 6, slidesToScroll = 6)
        
        overlay <- slickR(glue("diagnostics/single_pot/overlay/{chunks[[input$chunk]]}.jpeg"), height = 200) + opts
        mask <- slickR(glue("diagnostics/single_pot/mask/{chunks[[input$chunk]]}.png"), height = 200) + opts + settings(arrows = F)
        crop <- slickR(glue("diagnostics/single_pot/crop/{chunks[[input$chunk]]}.jpeg"), height = 200) + opts + settings(arrows = F)
        names <- slickR(as.character(chunks[[input$chunk]]), slideType = 'p') + opts + settings(arrows = F)
        overlay %synch% (crop %synch% (mask %synch% names))
    })
    session$onSessionEnded(function() {
        stopApp()
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
