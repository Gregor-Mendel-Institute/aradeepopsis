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
    .fork { img ->
      images: dimensions: img
      format: img.extension
    }
    .set { ch_images }

def imagetype = ch_images.format.unique().getVal()

assert imagetype == 'png' || imagetype == 'jpeg' || imagetype == 'jpg' : "ERROR: Only png or jpeg files are supported"

process get_dimensions {
    input:
        file(images) from ch_images.dimensions.collect() 
    output:
        stdout ch_maxdimensions
    script:
"""
#!/usr/bin/env python

import glob
import imagesize

print(max(imagesize.get(img) for img in glob.glob('*')))
"""
}

process build_TFRecords {
    publishDir "${params.outdir}/shards", mode: 'copy'
    input:
        file(images) from ch_images.images.buffer(size:params.chunksize, remainder: true)
    output:
        file('*.tfrecord') into ch_shards

    script:
def format = imagetype == 'png' ?  'png' : 'jpeg'
"""
#!/usr/bin/env python

import logging
import os

import tensorflow as tf

from data_record import create_record

logger = tf.get_logger()

images = tf.io.gfile.glob('*.${format}')

broken = 0

with tf.io.TFRecordWriter('chunk.tfrecord') as writer:
  for i in range(len(images)):
    filename = os.path.basename(images[i])
    image_data = tf.io.gfile.GFile(images[i], 'rb').read()
    try:
      image = tf.image.decode_${format}(image_data, 3)
    except tf.errors.InvalidArgumentError:
      logger.info("%s is not a valid ${format} image" % filename)
      broken += 1
      continue
    height, width = image.shape[:2]

    record = create_record(image_data, filename, '${format}', height, width, 3)
    writer.write(record.SerializeToString())

logger.info("Converted %d ${format} images to tfrecord, found %d broken images" % (len(images) - broken, broken))
"""
}

process run_prediction {
    publishDir "${params.outdir}/predictions", mode: 'copy',
        saveAs: { filename ->
                    if (filename.startsWith("mask_")) "mask/$filename"
                    else if (filename.startsWith("convex_hull_")) "convex_hull/$filename"
                    else null
                }
    input:
        file(shard) from ch_shards
        val(dim) from ch_maxdimensions
    output:
        file('*.csv') into results
        file('*.png') into predictions

    script:
def scale = params.multiscale ? 'multi' : 'single'
def mask = params.save_mask ? 'True' : 'False'
def hull = params.save_hull ? 'True' : 'False'
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

for index, sample in dataset:
        filename = sample['filename'].numpy()[0].decode('utf-8')
        logger.info("Running prediction on image %s (%d/%d)" % (filename,index, ${params.chunksize}))
        original_image =  sample['image'].numpy()
        segmentation = predict(sample['image'])
        measure_traits(np.squeeze(segmentation),
                                   np.squeeze(original_image),
                                   filename,
                                   save_mask=True,
                                   save_hull=False,
                                   get_regionprops=True,
                                   label_names=['background', 'rosette'],
                                   channelstats=True)
"""
}
 
results
 .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir, keepHeader: true, skip: 1)
