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

Channel
    .fromPath(params.images, checkIfExists: true)
    .buffer(size:params.chunksize, remainder: true)
    .set { ch_images }

process build_records {
    publishDir "${params.outdir}/shards", mode: 'copy'
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
    max_dimension = 521
    
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
                    else if (filename.startsWith("img_")) "img/$filename"
                    else if (filename.startsWith("diag_")) "sidebyside/$filename"
                    else null
                }
    input:
        file(shard) from ch_shards
    output:
        file('*.csv') into results
        file('*.png') into ch_masks

    script:
def scale = params.multiscale ? 'multi' : 'single'
def mask = params.save_mask ? 'True' : 'False'
def hull = params.save_hull ? 'True' : 'False'
def crop = params.save_rosette ? 'True' : 'False'
def diag = params.save_diagnostics ? 'True' : 'False'
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

with tf.io.gfile.GFile('${baseDir}/model/frozengraph/${scale}.pb', "rb") as f:
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
        original_image =  sample['image'].numpy()
        raw_segmentation = predict(sample['image'])
        ratio = sample['resize_factor'].numpy()
        
        original_image = np.squeeze(original_image)
        segmentation = np.squeeze(raw_segmentation)
        measure_traits(segmentation,
                       original_image,
                       filename,
                       save_mask=${mask},
                       save_rosette=${crop},
                       save_diagnostics=${diag},
                       save_histogram=${histogram},
                       save_hull=${hull},
                       label_names=['background','rosette'],
                       scale_ratio=ratio
                       )
"""
}

process draw_diagnostics {
    publishDir "${params.outdir}/diagnostics", mode: 'copy', overwrite: false

    input:
        file(masks) from ch_masks
    output:
        path('*.png') into diagnostics

    script:
"""
#!/usr/bin/env bash

montage mask_*png -background 'black' -font Ubuntu-Condensed -geometry 200x200 -set label '%f' -fill white \$RANDOM.png
"""
}

results
 .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir)
