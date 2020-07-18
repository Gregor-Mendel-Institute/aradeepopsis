#!/usr/bin/env nextflow

/*
Copyright (C) 2019-2020 Patrick Hüther

This file is part of araDeepopsis.
araDeepopsis free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

araDeepopsis is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with araDeepopsis.  If not, see <https://www.gnu.org/licenses/>.
*/

/*
========================================================================================
                            a r a D e e p o p s i s
========================================================================================
 Nextflow pipeline to run semantic segmentation on plant rosette images with deepLab V3+
 #### Author
 Patrick Hüther <patrick.huether@gmi.oeaw.ac.at>
----------------------------------------------------------------------------------------
*/
nextflow.preview.dsl=2
log.info """

#################################################################################
###############    ##############################################################
#############         ###########################################################
############             #####################     ##############################
############                ##############          #############################
###########                  ############            ############################
############                  #########              ############################
############                   #######               ############################
#############                   ######              #############################
#############                   ######             ##############################
##############                  #######         #################################
################               ########    ######################################
###################            ########  ########################################
####################           ######## #########################################
####################     ##### ####### #######      #############################
####################     ######  ##### ####         #############################
#####################      #####  ###              ##########         ###########
##########################                       ########                   #####
#############################                  #########                      ###
#############################                                                  ##
###############   ###########              ##########                           #
#########             ####      ###         ##########                          #
######                     ### ##### ######## #########                        ##
####                    #####  ##### #########   #######                   ######
###                     ###    #####  ########      ########         ############
##                     ####    ####       ####        ###########################
##                     ###########         #####      ###########################
#                    ###########            ######  #############################
#                 #############              ####################################
###           #################               ###################################
###############################               ###################################
###############################               ###################################
###############################               ###################################
###############################               ###################################
################################              ###################################
#################################            ####################################
##################################         ######################################
####################################    #########################################
#################################################################################

                        ┌─┐┬─┐┌─┐╔╦╗╔═╗╔═╗╔═╗┌─┐┌─┐┌─┐┬┌─┐
                        ├─┤├┬┘├─┤ ║║║╣ ║╣ ╠═╝│ │├─┘└─┐│└─┐
                        ┴ ┴┴└─┴ ┴═╩╝╚═╝╚═╝╩  └─┘┴  └─┘┴└─┘
                        
"""


// validate parameters
ParameterChecks.checkParams(params)

log.info """
=================================================================================
Current user              : $USER
Current path              : $PWD
Pipeline directory        : $baseDir
Working directory         : $workDir
Current profile           : ${workflow.profile}

Pipeline parameters
=========================
    --model               : ${params.masks ? '-' : params.model}
    --outdir              : ${params.outdir}
    --images              : ${params.images}
    --chunksize           : ${params.chunksize}
    --shiny               : ${params.shiny}
    --multiscale          : ${params.masks || params.model == 'DPP' ? '-' : params.multiscale}
    --ignore_senescence   : ${params.masks || params.model == 'A' ? "-" : params.ignore_senescence}
    --summary_diagnostics : ${params.summary_diagnostics}
    --save_mask           : ${params.save_mask}
    --save_overlay        : ${params.save_overlay}
    --save_rosette        : ${params.save_rosette}
    --save_overlay        : ${params.save_hull}
    --masks               : ${params.masks}
    --dpp_checkpoint      : ${params.model == 'DPP' ? params.dpp_checkpoint : '-'}
    --ignore_label        : ${params.model in ['A','B','C'] ? "-" : params.ignore_label}
    --label_spec          : ${params.label_spec ? params.label_spec : '-'}
=================================================================================
""".stripIndent()

switch(params.model) {
    case 'A':
        model = params.multiscale ? 'https://www.dropbox.com/s/19eeq3yog975otz/1_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/ejpkgnvsv9p9s5d/1_class_singlescale.pb?dl=1'
        labels = "class_background=0,class_norm=1"
        ignore_label = "None"
        break
    case 'B':
        model = params.multiscale ? 'https://www.dropbox.com/s/9m4wy990ajv7cmg/2_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/s808kcq9jgiyko9/2_class_singlescale.pb?dl=1'
        labels = "class_background=0,class_norm=1,class_senesc=2"
        ignore_label = params.ignore_senescence ? "2" : "None"
        break
    case 'C':
        model = params.multiscale ? 'https://www.dropbox.com/s/xwnqytcf6xzdumq/3_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/1axmww7cqor6i7x/3_class_singlescale.pb?dl=1'
        labels = "class_background=0,class_norm=1,class_senesc=2,class_antho=3"
        ignore_label = params.ignore_senescence ? "2" : "None"
        break
    case 'DPP':
        model = [
                params.dpp_checkpoint  + 'checkpoint',
                params.dpp_checkpoint  + 'tfhSaved.data-00000-of-00001',
                params.dpp_checkpoint  + 'tfhSaved.index',
                params.dpp_checkpoint  + 'tfhSaved.meta',
                ]
        labels = !params.label_spec ? "class_background=0,class_norm=1" : params.label_spec
        ignore_label = !params.ignore_label ? 'None' : params.ignore_label
        break
}

def chunk_idx = 1

Channel
    .fromPath(params.images, checkIfExists: true)
    .set {images}

if ( params.masks ) {
    Channel
        .fromPath(params.masks, checkIfExists: true)
        .cross(images) {it -> it.name}
        .map { plant -> [mask:plant[0], image:plant[1]] }
        .buffer(size: params.chunksize, remainder: true)
        .map { chunk -> [chunk_idx++, chunk.image, chunk.mask, file('dummy')] }
        .set { ch_images }

    if (!params.label_spec) {
        log.info """
        ERROR! The --masks parameter requires a comma-separated list of class names and their corresponding pixel values have to be provided.
        Example: --label_spec 'class_background=0,class_norm=255' (quotation marks are required!)
        """.stripIndent()
        exit(1)
    }

    labels = params.label_spec
    ignore_label = !params.ignore_label ? 'None' : params.ignore_label
} else {
    images
        .buffer(size: params.chunksize, remainder: true)
        .map { chunk -> [chunk_idx++, chunk] }
        .set { ch_images }
}

Channel
    .fromPath(model, glob: false, checkIfExists: true)
    .set { ch_model }

Channel
    .fromPath("$baseDir/assets/shiny/app.R", checkIfExists: true)
    .collectFile(name: 'app.R', storeDir: "$params.outdir")
    .set { ch_shinyapp }

workflow {
    if (!params.masks) {

        include build_records from './modules/buildRecords'
        build_records(ch_images)

        if (params.model == 'DPP') {

            include run_predictions_DPP as run_predictions from './modules/runPredictionsDPP'
            run_predictions(ch_model.collect(), build_records.out.ch_shards)

        } else {

            include run_predictions as run_predictions from './modules/runPredictions'
            run_predictions(ch_model, build_records.out.ch_shards)

        }

        build_records.out.ch_originals
            .join(run_predictions.out.ch_predictions)
            .join(build_records.out.ch_ratios)
            .set {ch_segmentations}

    }

    include extract_traits from './modules/extractTraits'
    extract_traits(params.masks ? ch_images : ch_segmentations, labels, ignore_label)

    extract_traits.out.ch_results
        .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir, keepHeader: true)
        .set {ch_resultfile}

    if (params.summary_diagnostics) {

        extract_traits.out.ch_masks
            .concat(extract_traits.out.ch_overlays, extract_traits.out.ch_crops)
            .set { ch_diagnostics }

        include draw_diagnostics from './modules/drawDiagnostics'
        draw_diagnostics(ch_diagnostics)
    }
    if (params.shiny) {

        include launch_shiny from './modules/launchShiny'
        launch_shiny(ch_resultfile, ch_shinyapp, labels)
    
    }
}

workflow.onError {
    if (workflow.exitStatus == 137) {
        log.error """
        ####################
        ERROR: Out of memory
        ####################
        The current pipeline configuration requires at least ${params.multiscale ? '12GB' : '6GB'} of RAM.
        """.stripIndent()
    }
}