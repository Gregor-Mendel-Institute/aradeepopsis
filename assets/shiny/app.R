library(shiny)
library(slickR)
library(tidyverse)
library(radarchart)
library(glue)
library(shinycssloaders)

data <- read_csv("aradeepopsis_traits.csv") %>% na.omit()

# Define UI
ui <- navbarPage(title="araDeepopsis",
           tabPanel("Rosette Carousel",
                    slickROutput("slickr",width='100%',height='400px') %>% withSpinner()
           ),
           tabPanel("Rosette Explorer",
               inputPanel(
                   selectInput("files",label="Select Image:", choices=data$file)
                    ),
               navlistPanel(id='tabset1',
                   tabPanel("Overlay",value=0,imageOutput("overlay")),
                   tabPanel("Mask",value=0,imageOutput("mask")),
                   tabPanel("Rosette",value=0,imageOutput("rosette")),
                   tabPanel("Leaf Classification",value=0,chartJSRadarOutput("radar", height = "100"))
                ),
            ),
            tabPanel("Rosette Statistics",
                 inputPanel(
                 selectInput("slidefiles",label="Select Image:", choices=data$file),
                     conditionalPanel(
                         condition="input.tabset2 == 1",
                         selectInput("traits","Select Trait:",choices = colnames(data %>% select(-file,-format)), selected = "rosette"))
                 ),
                navlistPanel(id='tabset2',
                        tabPanel("Basic Information",value=0,verbatimTextOutput("info")),
                        tabPanel("Overall distribution",value=0,plotOutput("histograms")),
                        tabPanel("Per-trait distribution",value=1,imageOutput("jitter"))
                )
            ),
            tabPanel("Rosette Experiment",
                    fileInput("metadata",label = "Select file"),
                    tableOutput("meta"),
                    textInput("IDcolumn", "Enter column containing unique identifier"),
                    textInput("DATEcolumn", "Enter column containing date"),
                    textInput("FILEcolumn", "Enter column containing filename")
            )
    )

server <- function(input, output, session) {

    output$mask <- renderImage({
        list(src = normalizePath(file.path('diagnostics/single_pot/mask',glue(input$files, '.png'))),width=400,height=400)
    }, deleteFile = FALSE)
    output$rosette <- renderImage({
        list(src = normalizePath(file.path('diagnostics/single_pot/crop',glue(input$files, '.jpeg'))),width=400,height=400)
    }, deleteFile = FALSE)
    output$overlay <- renderImage({
        list(src = normalizePath(file.path('diagnostics/single_pot/overlay',glue(input$files, '.jpeg'))),width=400,height=400)
    }, deleteFile = FALSE)
    output$radar = renderChartJSRadar({
        data %>%
            filter(file == input$files) %>% 
            select(one_of(c("rosette","anthocyanin","senescent"))) %>% 
            pivot_longer(everything(),names_to = "Label") %>% 
            mutate(value=value/sum(value)*100) %>% 
            chartJSRadar(.,maxScale = 100,scaleStartValue=0,scaleStepWidth = 25, showLegend = F)

    })
    output$histograms = renderPlot({
        data %>% pivot_longer(-c(file,format)) %>% 
            ggplot(aes(x=value)) +
                geom_histogram(bins=200) + 
                facet_wrap(~name,scales="free") +
                theme_bw()
#            select(file,input$traits) %>% 
#            ggplot(aes_string(input$traits)) + 
#                geom_histogram(bins = 200) +
#                theme_bw()
    })
    output$jitter = renderPlot(width=400,{
        data %>%
            select(file,input$traits) %>% 
            ggplot(aes_string(x=as.factor(input$traits),y=input$traits)) +
                geom_jitter(colour="black",alpha=0.3,size=5) +
                geom_jitter(data = {. %>% filter(file==input$slidefiles)}, colour="red", size=5) +
                xlab(element_blank()) +
                ylab("measurement") +
                theme_bw()
    })
    output$meta = renderTable({
       metafile <- input$metadata
       if (is.null(metafile))
           return(NULL)
       
       meta <- read_csv(metafile$datapath)
       head(meta)
    })
    output$info = renderText({
        glue("Measured ",ncol(data) - 2," traits for ",nrow(data)," rosettes")
    })
    output$slickr <- renderSlickR({
        withProgress(message = 'Loading images', value = 0, {
        n <- 5
        
        opts <- slickR::settings(slidesToShow= 6,
                         slidesToScroll = 6,
                         lazyLoad = 'ondemand')
        
        incProgress(1/n, detail = "Overlays")
        overlay <- slickR(list.files("diagnostics/single_pot/overlay/",full.names = TRUE,pattern="jpeg"),
                    height = 200,
                    width = '95%') + opts
        incProgress(1/n, detail = "Masks")
        mask <- slickR(list.files("diagnostics/single_pot/mask/",full.names = TRUE,pattern="png"),
                    height = 200,
                    width = '95%') + opts + slickR::settings(arrows = F)
        incProgress(1/n, detail = "Rosettes")
        crop <- slickR(list.files("diagnostics/single_pot/crop/",full.names = TRUE,pattern="jpeg"),
                    height = 200,
                    width = '95%') + opts + slickR::settings(arrows = F)
        incProgress(1/n, detail = "Names")
        names <- slickR(list.files("diagnostics/single_pot/mask/",pattern="png") %>% str_remove(.,".png"), slideType = 'p') + opts + slickR::settings(arrows = F)
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
