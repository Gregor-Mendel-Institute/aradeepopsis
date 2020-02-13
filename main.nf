#!/usr/bin/env nextflow

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
MMMMMMMMMMMNOl;,;:lx0NWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMNx:,,,,,,;:lxOXWMMMMMMMMMMMMMMMMMMMWWWWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMWk;,,,,,,,,,,,;cd0WMMMMMMMMMMMMMWKkdollodOXWMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMKl,,,,,,,,,,,,,,,:dKWMMMMMMMMWNKd:,,,,,,,;lKWMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMM0:,,,,,,,,,,,,,,,,,cOWMMMMMMXxoc,,,,,,,,,,;dNMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMM0c,,,,,,,,,,,,,,,,,,cOWMMMMXo;,,,,,,,,,,,,,oXMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMNd;,,,,,,,,,,,,,,,,,,oXMMMWk;,,,,,,,,,,,,,;xWMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMW0c,,,,,,,,,,,,,,,,,,:0MMMNd,,,,,,,,,,,,,;oXMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMNx;,,,,,,,,,,,,,,,,,;kWMMWO:,,,,,,,,,,,:xXMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMXd;,,,,,,,,,,,,,,,,;kWMMMNd;,,,,,,;:lxKWMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMNkc,,,,,,,,,,,,,,,c0MMMMWk;,,;cdk0XWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMWXkoc;,,,,,,,,,,;dNMMMMWk:;ckXWMMMWWWMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMWXk:,,,,,;;;,;xWMMMMNdld0WMWX0xdooxKWMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMWO:,,,,lOKkc;c0WMMWOcxXNXOoc;,,,,,lKMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMNx;,,,,c0WWXd::kNW0c;cooc;,,,,,,,,lKMMMMMWNK00OOO0KKXWWMMMMMMM
MMMMMMMMMMMMMMMMMWOc;;;;:ok0K0o;:dkl,,,,,,,,,,,,,;oKWMMN0xoc:;;,,,;;:cldxOKNMMM
MMMMMMMMMMMMMMMMMMWX000KXX0o::;,,,,,,,,,,,,,,,,:o0NMMW0o;,,,,,,,,,,,,,,,,,:lkNM
MMMMMMMMMMMMMMMMMMMMMMMMMMNd,,,,,,,,,,,,,,,,,,cONWMWXkc,,,,,,,,,,,,,,,,,,,,,;oK
MMMMMMMMMMWWNXXXXNWMMMMMMMKl,,,,,,,,,,,,,,,::::coddoc;,,,,,,,,,,,,,,,,,,,,,,,,l
MMMMMMWX0xdlcc:::clkKWMMMMXl,,,,,,,,,,,,,,cOXK00Okdl;,,,,,,,,,,,,,,,,,,,,,,,,,;
MMMMW0dc;,,,,,,,,,,,:dO00Od:,,;lxx:,,,,,,,:d0WMMMMWNx;,,,,,,,,,,,,,,,,,,,,,,,,;
MMN0o:,,,,,,,,,,,,,,,,,;:lxko;oXWKl,cxOOOOkocoOKNWMMXo,,,,,,,,,,,,,,,,,,,,,,,:x
WKo;,,,,,,,,,,,,,,,,,,,cOKko:;dNMXo,l0WMMMMWk;,:cokKWKo;,,,,,,,,,,,,,,,,,;cokKW
0c,,,,,,,,,,,,,,,,,,,,:ONx;,,,lKW0c,,cx0KWMWO:,,,,,ckNN0xoc::;;;;;::cloxk0NWMMM
d,,,,,,,,,,,,,,,,,,,,,oXWO:,,:xXKl;,,,,;:dKW0:,,,,,,:OWMMWNXKK00KKKXNWWMMMMMMMM
c,,,,,,,,,,,,,,,,,,,,:OWMWKkkKKkc,,,,,,,,,l0Nkc,,,,,:OWMMMMMMMMMMMMMMMMMMMMMMMM
;,,,,,,,,,,,,,,,,,,:o0WMMMMMMXd;,,,,,,,,,,,lKWKdc::lONMMMMMMMMMMMMMMMMMMMMMMMMM
;,,,,,,,,,,,,,,,:lxKNMMMMMMMWk;,,,,,,,,,,,,;oXMWNKKNWMMMMMMMMMMMMMMMMMMMMMMMMMM
klc:;;;;;;;:coxOKWMMMMMMMMMMXo,,,,,,,,,,,,,,:kWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
WWNXKK0000KXNWMMMMMMMMMMMMMMKl,,,,,,,,,,,,,,,oXMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMKl,,,,,,,,,,,,,,,cKMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMKc,,,,,,,,,,,,,,,c0MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMXo,,,,,,,,,,,,,,,lKMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMW0l,,,,,,,,,,,,,:kWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMWKl;,,,,,,,,,,:kNMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWXx:;,,,,,,:o0WMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMW0o:,,:coONMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM

                        ┌─┐┬─┐┌─┐╔╦╗╔═╗╔═╗╔═╗┌─┐┌─┐┌─┐┬┌─┐
                        ├─┤├┬┘├─┤ ║║║╣ ║╣ ╠═╝│ │├─┘└─┐│└─┐
                        ┴ ┴┴└─┴ ┴═╩╝╚═╝╚═╝╩  └─┘┴  └─┘┴└─┘
                        
"""

// validate parameters
ParameterChecks.checkParams(params)

switch(params.leaf_classes) {
    case 1:
        model = params.multiscale ? 'https://www.dropbox.com/s/19eeq3yog975otz/1_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/ejpkgnvsv9p9s5d/1_class_singlescale.pb?dl=1'
        labels = "['background','rosette']"
        break
    case 2:
        model = params.multiscale ? 'https://www.dropbox.com/s/9m4wy990ajv7cmg/2_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/s808kcq9jgiyko9/2_class_singlescale.pb?dl=1'
        labels = "['background','rosette','senescent']"
        break
    case 3:
        model = params.multiscale ? 'https://www.dropbox.com/s/xwnqytcf6xzdumq/3_class_multiscale.pb?dl=1' : 'https://www.dropbox.com/s/1axmww7cqor6i7x/3_class_singlescale.pb?dl=1'
        labels = "['background','rosette','senescent','anthocyanin']"
        break
}

Channel
    .fromPath(params.images, checkIfExists: true)
    .buffer(size:params.chunksize, remainder: true)
    .set { ch_images }

Channel
    .fromPath(model, checkIfExists: true)
    .set { ch_model }

process build_records {
    input:
        file('images/*') from ch_images
    output:
        file('*.tfrecord') into ch_shards
        file('*txt') into invalid_images optional true
    script:
"""
#!/usr/bin/env python

import logging
import os

import tensorflow as tf

from data_record import create_record

logger = tf.get_logger()
logger.setLevel('INFO')

images = tf.io.gfile.glob('images/*')

count = len(images)
invalid = 0

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

    width, height = image.shape[:2]

    ratio = 1.0  
    max_dimension = 602
    
    if height * width > max_dimension**2:
        logger.info('%s: dimensions %d x %d are too large,' % (filename, height, width))
        ratio = max(height,width)/max_dimension
        new_height = int(height/ratio)
        new_width = int(width/ratio)
        logger.info('%s: resized to %d x %d (scale factor:%f)' % (filename, new_height, new_width,ratio))
        image = tf.image.resize(image,
                                size=[new_height,new_width],
                                preserve_aspect_ratio=True)
        image_data = tf.image.encode_png(tf.cast(image, tf.uint8)).numpy()
    
    record = create_record(image_data, filename, height, width, ratio, 3)
    writer.write(record.SerializeToString())
"""
}

invalid_images
 .collectFile(name: 'invalid_images.txt', storeDir: params.outdir)

process run_predictions {
    publishDir "${params.outdir}", mode: 'copy',
        saveAs: { filename ->
                    if (filename.startsWith("mask_")) "mask/$filename"
                    else if (filename.startsWith("convex_hull_")) "convex_hull/$filename"
                    else if (filename.startsWith("crop_")) "crop/$filename"
                    else if (filename.startsWith("histogram_")) "histogram/$filename"
                    else if (filename.startsWith("img_")) "original/$filename"
                    else if (filename.startsWith("diag_")) "diagnostics/$filename"
                    else null
                }
    input:
        file(model) from ch_model
        each shard from ch_shards
    output:
        file('*.csv') into results
        file('*.png') into ch_overlays

    script:
def overlay = params.save_overlay ? 'True' : 'False'
def mask = params.save_mask ? 'True' : 'False'
def org = params.save_original ? 'True' : 'False'
def hull = params.save_hull ? 'True' : 'False'
def crop = params.save_rosette ? 'True' : 'False'
def histogram = params.save_histogram ? 'True' : 'False'
"""
#!/usr/bin/env python

import logging
import numpy as np
import time

import tensorflow as tf

from data_record import parse_record
from frozen_graph import wrap_frozen_graph
from traits import measure_traits

logger = tf.get_logger()
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
        original_image = sample['image'].numpy()
        raw_segmentation = predict(sample['image'])
        ratio = sample['resize_factor'].numpy()
        
        original_image = np.squeeze(original_image)
        segmentation = np.squeeze(raw_segmentation)
        measure_traits(segmentation,
                       original_image,
                       filename,
                       save_overlay=${overlay},
                       save_mask=${mask},
                       save_original=${org},
                       save_rosette=${crop},
                       save_histogram=${histogram},
                       save_hull=${hull},
                       label_names=${labels},
                       scale_ratio=ratio
                       )
"""
}

process draw_diagnostics {
    publishDir "${params.outdir}/diagnostics", mode: 'copy'

    input:
        file(masks) from ch_overlays
    output:
        path('*.png') into diagnostics

    script:
def polaroid = params.polaroid ? '+polaroid' : ''
"""
#!/usr/bin/env bash

montage overlay_*png -background 'black' -font Ubuntu-Condensed -geometry 200x200 -set label '%f' -fill white ${polaroid} "\${PWD##*/}.png"
"""
}

results
 .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir)
