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

switch(params.model) {
    case 'A':
        model = params.multiscale ? 'https://www.dropbox.com/s/19eeq3yog975otz/1_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/ejpkgnvsv9p9s5d/1_class_singlescale.pb?dl=1'
        labels = "['class_background','class_norm']"
        break
    case 'B':
        model = params.multiscale ? 'https://www.dropbox.com/s/9m4wy990ajv7cmg/2_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/s808kcq9jgiyko9/2_class_singlescale.pb?dl=1'
        labels = "['class_background','class_norm','class_senesc']"
        break
    case 'C':
        model = params.multiscale ? 'https://www.dropbox.com/s/xwnqytcf6xzdumq/3_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/1axmww7cqor6i7x/3_class_singlescale.pb?dl=1'
        labels = "['class_background','class_norm','class_senesc','class_antho']"
        break
}

def chunk_idx = 1

Channel
    .fromPath(params.images, checkIfExists: true)
    .buffer(size:params.chunksize, remainder: true)
    .map { chunk -> [chunk_idx++, chunk] }
    .set { ch_images_records }

Channel
    .fromPath(model, glob: false, checkIfExists: true)
    .set { ch_model }

Channel
    .fromPath("$baseDir/assets/color_legend/model_${params.model}.png", checkIfExists: true)
    .collectFile(name: 'colorlegend.png', storeDir: "$params.outdir/diagnostics")

Channel
    .fromPath("$baseDir/assets/shiny/app.R", checkIfExists: true)
    .collectFile(name: 'app.R', storeDir: "$params.outdir")
    .set {ch_shinyapp}

process build_records {
    stageInMode 'copy'
    input:
        tuple val(index), path('images/*') from ch_images_records
    output:
        tuple val(index), path('*.tfrecord') into ch_shards
        tuple val(index), path('ratios.p'), path('images/*', includeInputs: true) into ch_images_traits
        path('*.txt') into invalid_images optional true
    script:
        """
        #!/usr/bin/env python

        import logging
        import os
        import pickle

        import tensorflow as tf

        from data_record import create_record

        logger = tf.get_logger()
        logger.propagate = False
        logger.setLevel('INFO')

        images = tf.io.gfile.glob('images/*')

        count = len(images)
        invalid = 0
        scale_factors = {}

        with tf.io.TFRecordWriter('chunk.tfrecord') as writer:
            for i in range(count):
                filename = os.path.basename(images[i])
                image_data = tf.io.gfile.GFile(images[i], 'rb').read()
                try:
                    image = tf.io.decode_image(image_data, channels=3)
                except tf.errors.InvalidArgumentError:
                    logger.info("%s is either corrupted or not a supported image format" % filename)
                    invalid += 1
                    with open("invalid.txt", "a") as broken:
                        broken.write(f'{filename}\\n')
                    continue

                height, width = image.shape[:2]
                max_dimension = 602
                ratio = 1.0

                if height * width > max_dimension**2:
                    logger.info('%s: dimensions %d x %d are too large,' % (filename, height, width))
                    ratio = max(height,width)/max_dimension
                    new_height = int(height/ratio)
                    new_width = int(width/ratio)
                    logger.info('%s: resized to %d x %d (scale factor:%f)' % (filename, new_height, new_width, ratio))
                    image = tf.image.resize(image, size=[new_height,new_width], preserve_aspect_ratio=False, antialias=True)
                    image_data = tf.image.encode_png(tf.cast(image, tf.uint8)).numpy()
                    tf.io.write_file(os.path.join(f'images/{filename}'), image_data)

                scale_factors[filename] = ratio
                record = create_record(image_data=image_data,
                                    filename=filename,
                                    height=height,
                                    width=width,
                                    ratio=ratio)

                writer.write(record.SerializeToString())

        pickle.dump(scale_factors, open("ratios.p", "wb"))
        """
}

invalid_images
 .collectFile(name: 'invalid_images.txt', storeDir: params.outdir)

process run_predictions {
    input:
        path(model) from ch_model.collect()
        tuple val(index), path(shard) from ch_shards
    output:
        tuple val(index), path('*.png') into ch_predictions

    script:
        """
        #!/usr/bin/env python

        import logging

        import tensorflow as tf

        from data_record import parse_record
        from frozen_graph import wrap_frozen_graph

        logger = tf.get_logger()
        logger.propagate = False
        logger.setLevel('INFO')

        with tf.io.gfile.GFile('${model}', "rb") as f:
            graph_def = tf.compat.v1.GraphDef()
            graph_def.ParseFromString(f.read())

        predict = wrap_frozen_graph(
            graph_def,
            inputs='ImageTensor:0',
            outputs='SemanticPredictions:0')

        dataset = (
            tf.data.TFRecordDataset('${shard}')
            .map(parse_record)
            .batch(1)
            .prefetch(1)
            .enumerate(start=1))

        size = len(list(dataset))

        for index, sample in dataset:
            filename = sample['filename'].numpy()[0].decode('utf-8')
            logger.info("Running prediction on image %s (%d/%d)" % (filename,index,size))
            raw_segmentation = predict(sample['original'])[0][:, :, None]
            output = tf.image.encode_png(tf.cast(raw_segmentation, tf.uint8))
            tf.io.write_file(filename.rsplit('.', 1)[0] + '.png',output)
        """
}

process extract_traits {
    publishDir "${params.outdir}/diagnostics", mode: 'copy',
        saveAs: { filename ->
                if (filename.startsWith("mask_")) "mask/$filename"
                else if (filename.startsWith("overlay_")) "overlay/$filename"
                else if (filename.startsWith("crop_")) "crop/$filename"
                else if (filename.startsWith("hull_")) "convex_hull/$filename"
                else null
            }

    input:
        tuple val(index), path(ratios), path("original_images/*"), path("raw_masks/*") from ch_images_traits.join(ch_predictions)
    output:
        path('*.csv') into ch_results
        tuple val(index), val('mask'), path('mask_*') into ch_masks optional true
        tuple val(index), val('overlay'), path('overlay_*') into ch_overlays optional true
        tuple val(index), val('crop'), path('crop_*') into ch_crops optional true
        tuple val(index), val('hull'), path('hull_*') into ch_hull optional true

    script:
        """
        #!/usr/bin/env python

        import os
        import pickle

        from traits import measure_traits, draw_diagnostics, load_images

        ratios = pickle.load(open('ratios.p',"rb"))

        masks, originals = load_images()

        for index, name in enumerate(originals.files):
            measure_traits(masks[index],
                        originals[index],
                        ratios[os.path.basename(name)],
                        os.path.basename(name),
                        ignore_senescence=${params.ignore_senescence.toString().capitalize()},
                        label_names=${labels})
            draw_diagnostics(masks[index],
                            originals[index],
                            os.path.basename(name),
                            save_overlay=${params.save_overlay.toString().capitalize()},
                            save_mask=${params.save_mask.toString().capitalize()},
                            save_rosette=${params.save_rosette.toString().capitalize()},
                            save_hull=${params.save_hull.toString().capitalize()},
                            ignore_senescence=${params.ignore_senescence.toString().capitalize()})
        """
}

process draw_diagnostics {
    publishDir "${params.outdir}/diagnostics", mode: 'copy',
        saveAs: { filename ->
                    if (filename.startsWith("mask_")) "summary/mask/$filename"
                    else if (filename.startsWith("overlay_")) "summary/overlay/$filename"
                    else if (filename.startsWith("crop_")) "summary/crop/$filename"
                    else null
                }
    input:
        tuple val(index), val(type), path(image) from ch_masks.concat(ch_overlays,ch_crops)
    output:
        path('*.jpeg')
    when:
        params.summary_diagnostics

    script:
        def polaroid = params.polaroid ? '+polaroid' : ''
        """
        #!/usr/bin/env bash

        montage * -background 'black' -font Ubuntu-Condensed -geometry 200x200 -set label '%t' -fill white ${polaroid} "${type}_chunk_${index}.jpeg"
        """
}

ch_results
 .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir, keepHeader: true)
 .set {ch_resultfile}

process launch_shiny {
    containerOptions { workflow.profile.contains('singularity') ? '' : '-p 44333:44333' }
    executor 'local'
    cache false

    input:
        path ch_resultfile
        path app from ch_shinyapp
    when:
        params.shiny
    script:
        def ip = "uname".execute().text.trim() == "Darwin" ? "localhost" : "hostname -i".execute().text.trim()
        log.error"""
        Visit the shiny server running at ${"http://"+ip+':44333'} to inspect the results.
        Closing the browser window will terminate the pipeline.
        """.stripIndent()
        """
        R -e "shiny::runApp('${app}', port=44333, host='0.0.0.0')"
        """
}
