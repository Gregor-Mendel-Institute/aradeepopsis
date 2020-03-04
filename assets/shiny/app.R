library(shiny)
library(slickR)
library(tidyverse)
library(radarchart)
library(glue)
library(lubridate)
library(shinycssloaders)
library(shinythemes)

data <- read_csv("aradeepopsis_traits.csv")

# Define UI
ui <- navbarPage(title="araDeepopsis", theme = shinytheme("flatly"),
           tabPanel("Rosette Carousel",
               slickROutput("slickr",width='100%',height='400px') %>% withSpinner()
           ),
           tabPanel("Rosette Explorer",
               sidebarPanel(
                   selectInput("explorer_files",label="Select Image:", choices=data$file)
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
                     selectInput("statistics_files",label="Select Image:", choices=data$file),
                     conditionalPanel(
                             condition="input.tabset2 == 1",
                             selectInput("statistics_traits","Select Trait:", choices = colnames(data %>% select(-file,-format)), selected = "rosette"))
                 ),
                mainPanel(
                    tabsetPanel(id='tabset2',
                            tabPanel("Basic Information",value=0,verbatimTextOutput("info")),
                            tabPanel("Trait Histogram",value=1,plotOutput("histograms")),
                            tabPanel("Trait Jitterplot",value=1,imageOutput("jitter"))
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
                        selectInput("exp_traits","Select Trait:", choices = colnames(data %>% select(-file,-format)), selected = "rosette")
                    ),
                    mainPanel(
                        tabsetPanel(id='tabset3',
                            tabPanel("Traits over time",value=0,plotOutput("timeline"))
                        )
                    )
            )
    )

server <- function(input, output, session) {

    output$mask <- renderImage({
        list(src = normalizePath(file.path('diagnostics/single_pot/mask',glue(input$explorer_files, '.png'))),width=400,height=400)
    }, deleteFile = FALSE)
    output$rosette <- renderImage({
        list(src = normalizePath(file.path('diagnostics/single_pot/crop',glue(input$explorer_files, '.jpeg'))),width=400,height=400)
    }, deleteFile = FALSE)
    output$overlay <- renderImage({
        list(src = normalizePath(file.path('diagnostics/single_pot/overlay',glue(input$explorer_files, '.jpeg'))),width=400,height=400)
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
        updateSelectInput(session, "file", choices = columns)
        updateSelectInput(session, "date", choices = columns)
        updateSelectInput(session, "id", choices = columns)
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
    glue("Measured ",ncol(data) - 2," traits for ",nrow(data)," rosettes")
    })
    output$slickr <- renderSlickR({
        withProgress(message = 'Loading images', value = 0, {
        n <- 5
        
        opts <- settings(slidesToShow = 6,
                         slidesToScroll = 6,
                         lazyLoad = 'ondemand')
        
        incProgress(1/n, detail = "Overlays")
        overlay <- slickR(list.files("diagnostics/single_pot/overlay/",full.names = TRUE, pattern = "jpeg"),
                    height = 200,
                    width = '95%') + opts
        incProgress(1/n, detail = "Masks")
        mask <- slickR(list.files("diagnostics/single_pot/mask/",full.names = TRUE,pattern = "png"),
                    height = 200,
                    width = '95%') + opts + settings(arrows = F)
        incProgress(1/n, detail = "Rosettes")
        crop <- slickR(list.files("diagnostics/single_pot/crop/",full.names = TRUE,pattern = "jpeg"),
                    height = 200,
                    width = '95%') + opts + settings(arrows = F)
        incProgress(1/n, detail = "Names")
        names <- slickR(list.files("diagnostics/single_pot/mask/",pattern="png") %>% str_remove(.,".png"), slideType = 'p') + opts + settings(arrows = F)
        merged <- overlay %synch% (crop %synch% (mask %synch% names))
        incProgress(1/n, detail = "Syncing ...")
        merged
        })
    })
    session$onSessionEnded(function() {
        stopApp()
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
