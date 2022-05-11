#!/usr/bin/env nextflow

/*
Copyright (C) 2019-2021 Patrick Hüther

This file is part of ARADEEPOPSIS.
ARADEEPOPSIS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ARADEEPOPSIS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ARADEEPOPSIS.  If not, see <https://www.gnu.org/licenses/>.
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
Pipeline directory        : $projectDir
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


include { ARADEEPOPSIS } from './workflows/aradeepopsis'

workflow {
    ARADEEPOPSIS()
}