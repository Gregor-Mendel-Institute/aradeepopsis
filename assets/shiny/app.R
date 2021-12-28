# Copyright (C) 2019-2021 Patrick Hüther
#
# This file is part of ARADEEPOPSIS.
# ARADEEPOPSIS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ARADEEPOPSIS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ARADEEPOPSIS.  If not, see <https://www.gnu.org/licenses/>.

library(shiny)
library(slickR)
library(tidyverse)
library(radarchart)
library(shinycssloaders)
library(shinythemes)
library(corrplot)
library(jpeg)

# raise file upload limit to 20MB
options(shiny.maxRequestSize=20*1024^2)

data <- read_csv("aradeepopsis_traits.csv") %>% arrange(file)

labels <- Sys.getenv(c("LABELS"),"class_background=0,class_norm=1,class_senesc=2,class_antho=3") %>% 
  str_replace_all(.,"=[:digit:]+","") %>% 
  str_split(.,",") %>% 
  unlist() %>% 
  tail(-1)

num_labels <- data %>% select(any_of(glue::glue("{labels}_area"))) %>% ncol()

imagenames <- data %>% select(file)
invalid <- ifelse(file.exists('invalid_images.txt'),length(read_lines('invalid_images.txt')),0)
traitcount <- ncol(data) - 2 # exclude filename and suffix
imagecount <- nrow(data)

# Define UI
ui <- navbarPage(title=a("aradeepopsis", href="https://github.com/Gregor-Mendel-Institute/aradeepopsis", target="_blank"), windowTitle = "ARADEEPOPSIS", id="nav", theme = shinytheme("flatly"), collapsible=TRUE,
		tabPanel("Rosette Carousel",
			sliderInput("chunk", label = "Select chunk:", min = 1, max = ceiling(imagecount/60), value = 1, width = '100%', step = 1),
			slickROutput("slickr", width='auto', height='auto') %>% withSpinner()
		),
		tabPanel("Rosette Explorer",
			sidebarPanel(
				selectizeInput("explorer_files",label="Select Image:", choices=NULL)
			),
			mainPanel(
				tabsetPanel(id='tabset1',type='pills',
					tabPanel("Overlay",value=0,imageOutput("overlay")),
					tabPanel("Mask",value=0,imageOutput("mask")),
					tabPanel("Convex Hull",value=0,imageOutput("hull")),
					tabPanel("Rosette",value=0,imageOutput("rosette")),
					tabPanel("Color Channels",value=0,plotOutput("color") %>% withSpinner()),
					tabPanel("Leaf Classification",value=1,chartJSRadarOutput("radar", height = "200") %>% withSpinner())
				),
			),
		),
		tabPanel("Rosette Statistics",
			sidebarPanel(
				verbatimTextOutput("info"),
				conditionalPanel(
					condition="input.tabset2 == 0",
					selectizeInput("correlations_type",label="Select Covariance method:", choices=c("pairwise.complete.obs", "complete.obs", "everything", "all.obs", "na.or.complete"))
				),
				conditionalPanel(
					condition="input.tabset2 > 0",
					selectizeInput("statistics_traits","Select Trait:", choices = colnames(data %>% select(-file,-format)), selected = "rosette"),
					conditionalPanel(
						condition="input.tabset2 == 2",
						selectizeInput("statistics_files",label="Select Image:", choices=NULL)
					),
				)
			),
			mainPanel(
				tabsetPanel(id='tabset2',type='pills',
					tabPanel("Trait Correlation",value=0,plotOutput("correlations") %>% withSpinner()),
					tabPanel("Trait Histogram",value=1,plotOutput("histograms") %>% withSpinner()),
					tabPanel("Trait Jitterplot",value=2,plotOutput("jitter") %>% withSpinner())
				)
			)
		),
		tabPanel("Rosette Experiment",
			sidebarPanel(
				fileInput("metadata_table",label = "Select file"),
				div(style = "overflow-x:scroll;", tableOutput("meta")),
				varSelectizeInput("file","Select column containing the filename", data = NULL),
				varSelectizeInput("date","Select column containing the timestamp", data = NULL),
				textInput("date_format",HTML('Enter timestamp <a href="https://rdrr.io/r/base/strptime.html">format</a>'),value="%y-%m-%d"),
				varSelectizeInput("groupvar","Select column to group by", data = NULL),
				actionButton("merge_data", "Analyze!"),
				conditionalPanel(
				  condition="input.tabset3 > 0",
				  selectizeInput("exp_traits","Select Trait:", choices = colnames(data %>% select(-file,-format)), selected = glue::glue("{labels[1]}_area"))
				)
			),
			mainPanel(
				tabsetPanel(id='tabset3',type='pills',
							tabPanel("Leaf states over time",value=0,plotOutput("leafstates") %>% withSpinner()),
							tabPanel("Traits over time",value=1,plotOutput("timeline") %>% withSpinner())
				)
			)
		),
	tags$style(type = 'text/css', '.navbar .navbar-brand {font-variant: small-caps;}')
)

server <- function(input, output, session) {
		# hide radarchart if there is only one class
		if (num_labels < 2) { hideTab(inputId = "tabset1", target = "1") }
		# nextflow report is only generated after the run has finished once, show the tab only for resumed runs
		if (dir.exists("www")) {
			appendTab("nav",
				tabPanel("Nextflow Report",
					tabsetPanel(id='tabset4',type='pills',
						tabPanel("Execution Report",value=0,htmlOutput("nf_report") %>% withSpinner()),
						tabPanel("Timeline",value=0,htmlOutput("nf_timeline") %>% withSpinner())
					)
				)
			)
		}
		# for large datasets it helps with performance if selection lists are done on the server-side
		updateSelectizeInput(session, "statistics_files", choices = c(imagenames), server = TRUE)
		updateSelectizeInput(session, "explorer_files", choices = c(imagenames), server = TRUE)

		output$mask <- renderImage(deleteFile=FALSE,{
			list(src = glue::glue("diagnostics/mask/mask_{input$explorer_files}.png"),width=600,height="auto")
		})
		output$hull <- renderImage(deleteFile=FALSE,{
			list(src = glue::glue("diagnostics/convex_hull/hull_{input$explorer_files}.png"),width=600,height="auto")
		})
		output$rosette <- renderImage(deleteFile=FALSE,{
			list(src = glue::glue("diagnostics/crop/crop_{input$explorer_files}.jpeg"),width=600,height="auto")
		})
		output$overlay <- renderImage(deleteFile=FALSE,{
			list(src = glue::glue("diagnostics/overlay/overlay_{input$explorer_files}.jpeg"),width=600,height="auto")
		})
		output$color <- renderPlot(width=600,height=600,{
	    img <- readJPEG(glue::glue("diagnostics/crop/crop_{input$explorer_files}.jpeg"))

	    r <- img[,,1] %>% as_tibble() %>% pivot_longer(everything()) %>% mutate(name=1)
	    g <- img[,,2] %>% as_tibble() %>% pivot_longer(everything()) %>% mutate(name=2)
	    b <- img[,,3] %>% as_tibble() %>% pivot_longer(everything()) %>% mutate(name=3)

	    bind_rows(r,g,b) %>%
	      mutate(channel=factor(name,labels=c('red','green','blue'))) %>%
	      ggplot(aes(x=value*255,fill=channel),alpha=0.5,color="black") +
	      geom_histogram(position="dodge",bins=30,col="black") +
	      theme_bw() +
	      facet_wrap(~channel,ncol=1) +
	      scale_x_continuous(breaks=c(0,255),limits=c(1,255)) +
	      xlab("pixel value") +
	      theme(legend.position = "None")
		})
		output$radar = renderChartJSRadar({
			data %>%
				filter(file == input$explorer_files) %>%
				select(any_of(glue::glue("{labels}_area"))) %>%
				pivot_longer(everything(),names_to = "Label") %>% 
				mutate(value=value/sum(value)*100) %>% 
				chartJSRadar(.,maxScale = 100,scaleStartValue = 0,scaleStepWidth = 25,showLegend = F)
		})
		output$histograms <- renderPlot(width=600,height=600,{
			data %>%
				select(file,input$statistics_traits) %>%
				ggplot(aes_string(input$statistics_traits)) +
				geom_histogram(bins = 100) +
				theme_bw()
		})
		output$jitter <- renderPlot(width=600,height=600,{
			data %>%
				select(file,input$statistics_traits) %>%
				ggplot(aes_string(x=as.factor(input$statistics_traits),y=input$statistics_traits)) +
				geom_jitter(colour="black",alpha=0.3,size=5) +
				geom_jitter(data = {. %>% filter(file==input$statistics_files)}, colour="red", size=5) +
				xlab(element_blank()) +
				ylab("measurement") +
				theme_bw()
		})
		output$correlations <- renderPlot(width=1000,height=1000,{
			data %>%
				select(-file,-format,-total_area) %>%
				cor(use=input$correlations_type) %>%
				corrplot(method="shade",tl.cex=1.0,tl.col="black",type="upper")
		})
		output$meta <- renderTable(striped = TRUE,width="100px",{
			filedata() %>% head(n=1)
		})

		filedata <- eventReactive(input$metadata_table,{
			metafile <- input$metadata_table
			req(metafile)
			table <- read_csv(metafile$datapath,col_types = cols(.default = "c"))
			columns = colnames(table)
			updateSelectizeInput(session, "file", choices = columns)
			updateSelectizeInput(session, "date", choices = columns)
			updateSelectizeInput(session, "groupvar", choices = columns)
			table
		})
		joined <- eventReactive(input$merge_data,{
			filedata() %>%
				mutate(file := !!input$file) %>%
				mutate(groupVar := as.factor(!!input$groupvar)) %>%
				mutate_at(.,.vars=vars(file),.funs=~tools::file_path_sans_ext(basename(.))) %>% 
				right_join(.,data, by="file") %>%
				mutate(dateVar := !!input$date %>% lubridate::parse_date_time(.,orders = input$date_format))
		})
		output$timeline <- renderPlot({
			joined() %>%
		    select(dateVar,groupVar,trait := !!input$exp_traits) %>%
		    ggplot(aes(x=dateVar,y=trait,colour=groupVar)) +
		    stat_summary(geom="line", size=1.5) +
		    stat_summary(geom="pointrange") +
				scale_color_viridis_d(option="A", end=0.9) +
		    labs(x="time",y="trait value",colour=element_blank()) +
				theme_bw()
		})
		output$leafstates <- renderPlot({
		  joined() %>%
		    select(file,groupVar,dateVar,matches("norm_area|antho_area|senesc_area")) %>%
		    pivot_longer(starts_with("class_"),names_to = "state") %>%
		    group_by(groupVar,dateVar,file) %>%
		    mutate(relativeFrac=value/sum(value)) %>%
		    ggplot(aes(x = dateVar, y = relativeFrac, colour=state)) +
		    stat_summary(geom="line", size=1.5) +
		    stat_summary(geom="pointrange") +
		    scale_color_manual(values = c("class_norm_area" = rgb(31,158,137, maxColorValue = 255),
		                                  "class_antho_area" = rgb(72,40,120, maxColorValue = 255),
		                                  "class_senesc_area" =  rgb(253,231,37, maxColorValue = 255))) +
		    scale_y_continuous(labels = scales::percent) +
		    labs(x="time",y="% of plant area",colour=element_blank()) +
			facet_wrap(~groupVar) +
		    theme_bw()
		})
		# show a description if Rosette Experiment is selected
		observeEvent(input$nav,{
			if(input$nav == "Rosette Experiment") {
				showModal(
					modalDialog(
						title="Experimental feature!",
						HTML("This feature is meant to add metadata to the pipeline result, allowing to visualize traits over time.<br>
						It requires a csv table with metadata that is then joined with the pipeline result.<br>
						<br>
						Such metadata has to contain one row per input image and the following columns:<br>
						- Filenames of the original images <br>
						- Timestamps when the images were recorded<br>
						- Variable(s) by which the result should be grouped (such as genotype or accession ID)<br>
						<br>
						Note: If the 'file' column of aradeepopsis_traits.csv is used to extract such metadata, trait columns should be removed before uploading")
					)
				)
			}
		})

		output$info <- renderText({
			glue::glue("Measured {traitcount} traits across {imagecount-invalid} rosettes ({invalid} failure(s))")
		})
		output$slickr <- renderSlickR({
			# split the filenames into chunks of 60, corresponding to 10 pages per chunk
			# this drastically improves page loading time
			chunks <- if (imagecount > 60) split(imagenames$file, ceiling(seq_along(imagenames$file)/60)) else split(imagenames$file, 1)
			
			opts <- settings(slidesToShow=6, slidesToScroll=6, responsive=htmlwidgets::JS("[{breakpoint: 1440,settings: {slidesToShow: 3,slidesToScroll: 3}},{breakpoint: 680,settings: {slidesToShow: 1,slidesToScroll: 1}}]"))
			
			overlay <- slickR(glue::glue("diagnostics/overlay/overlay_{chunks[[input$chunk]]}.jpeg"), height = 200) + opts
			mask <- slickR(glue::glue("diagnostics/mask/mask_{chunks[[input$chunk]]}.png"), height = 200) + opts + settings(arrows = F)
			crop <- slickR(glue::glue("diagnostics/crop/crop_{chunks[[input$chunk]]}.jpeg"), height = 200) + opts + settings(arrows = F)
			names <- slickR(as.character(chunks[[input$chunk]]), slideType = 'p') + opts + settings(arrows = F)
			overlay %synch% (crop %synch% (mask %synch% names))
		})
		output$nf_report <- renderUI({
			tags$iframe(seamless="seamless", src="execution_report.html", width="100%", height=1000)
		})
		output$nf_timeline <- renderUI({
			tags$iframe(seamless="seamless", src="execution_timeline.html", width="100%", height=1000)
		})
		session$onSessionEnded(function() {
			stopApp()
		})
}

# Run the application 
shinyApp(ui = ui, server = server)
