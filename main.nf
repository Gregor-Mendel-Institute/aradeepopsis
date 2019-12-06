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

import tensorflow as tf

with tf.Graph().as_default():
    decode_data = tf.compat.v1.placeholder(dtype=tf.string)
    session = tf.compat.v1.Session()

    decode = tf.image.decode_${format}(decode_data, channels=3)

filenames = tf.io.gfile.glob('*${format}')

def _bytes_feature(value):
  if isinstance(value, str):
    value = value.encode()
  return tf.train.Feature(bytes_list=tf.train.BytesList(value=[value]))

def _int64_feature(value):
  return tf.train.Feature(int64_list=tf.train.Int64List(value=[value]))

with tf.io.TFRecordWriter('chunk.tfrecord') as tfrecord_writer:
  for i in range(len(filenames)):
    image_data = tf.io.gfile.GFile(filenames[i], 'rb').read()
    image = session.run(decode, feed_dict={decode_data: image_data})
    height, width = image.shape[:2]

    example = tf.train.Example(features=tf.train.Features(feature={
                                        'image/encoded': _bytes_feature(image_data),
                                        'image/filename': _bytes_feature(filenames[i]),
                                        'image/format': _bytes_feature('${format}'),
                                        'image/height': _int64_feature(height),
                                        'image/width': _int64_feature(width),
                                        'image/channels': _int64_feature(3),
                                        }))
    tfrecord_writer.write(example.SerializeToString())
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
def multiscale = params.multiscale ? 'True' : 'False'
def mask = params.save_mask ? 'True' : 'False'
def hull = params.save_hull ? 'True' : 'False'
"""
#!/usr/bin/env python

import time
import numpy as np

import tensorflow as tf

from deeplab import common
from deeplab import model
from deeplab.datasets import data_generator
from traits import measure_traits

tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.INFO)

max_dim = ${dim}
crop_size_hw = [max_dim[1] + 1, max_dim[0] + 1]

dataset = data_generator.Dataset(
      dataset_name='rosettes',
      split_name='test',
      dataset_dir='.',
      batch_size=1,
      crop_size=[int(sz) for sz in crop_size_hw],
      min_resize_value=None,
      max_resize_value=None,
      resize_factor=None,
      model_variant='xception_65')

with tf.Graph().as_default():
    model_options = common.ModelOptions(
    outputs_to_num_classes={common.OUTPUT_TYPE: dataset.num_of_classes},
    crop_size=[int(sz) for sz in crop_size_hw],
    atrous_rates=[12,24,36],
    output_stride=8)

    samples = dataset.get_one_shot_iterator(chunk='${shard}').get_next()

    if ${multiscale}:
      tf.compat.v1.logging.info('Performing multi-scale test.')
      predictions = model.predict_labels_multi_scale(
          samples[common.IMAGE],
          model_options=model_options,
          eval_scales=[0.5, 0.75, 1.0, 1.25, 1.5, 1.75],
          add_flipped_images=True)
    else:
      tf.compat.v1.logging.info('Performing single-scale test.')
      predictions = model.predict_labels(
          samples[common.IMAGE],
          model_options=model_options,
          image_pyramid=None)

    predictions = predictions[common.OUTPUT_TYPE]

    if dataset.min_resize_value and dataset.max_resize_value:
      # Reverse the resizing and padding operations performed in preprocessing.
      # First, we slice the valid regions (i.e., remove padded region) and then
      # we resize the predictions back.
      original_image = tf.squeeze(samples[common.ORIGINAL_IMAGE])
      original_image_shape = tf.shape(original_image)
      predictions = tf.slice(
          predictions,
          [0, 0, 0],
          [1, original_image_shape[0], original_image_shape[1]])
      resized_shape = tf.to_int32([tf.squeeze(samples[common.HEIGHT]),
                                    tf.squeeze(samples[common.WIDTH])])
      predictions = tf.squeeze(
          tf.image.resize_images(tf.expand_dims(predictions, 3),
                                  resized_shape,
                                  method=tf.image.ResizeMethod.NEAREST_NEIGHBOR,
                                  align_corners=True), 3)

    tf.compat.v1.train.get_or_create_global_step()

    tf.compat.v1.logging.info(
        'Starting visualization at ' + time.strftime('%Y-%m-%d-%H:%M:%S',
                                                    time.gmtime()))

    scaffold = tf.compat.v1.train.Scaffold(init_op=tf.compat.v1.global_variables_initializer())
    session_creator = tf.compat.v1.train.ChiefSessionCreator(
                      scaffold=scaffold,
                      master='',
                      checkpoint_dir='${baseDir}/model')

    with tf.compat.v1.train.MonitoredSession(
      session_creator=session_creator, hooks=None) as sess:
      batch = 0

      while not sess.should_stop():
        tf.compat.v1.logging.info(
          'Running prediction on plant %d/%d', batch + 1, ${params.chunksize})
        
        (original_images,
        semantic_predictions,
        image_names,
        image_heights,
        image_widths) = sess.run([samples[common.ORIGINAL_IMAGE],
                        predictions,
                        samples[common.IMAGE_NAME],
                        samples[common.HEIGHT],
                        samples[common.WIDTH],
                        ])

        num_image = semantic_predictions.shape[0]
        for i in range(num_image):
          image_height = np.squeeze(image_heights[i])
          image_width = np.squeeze(image_widths[i])
          original_image = np.squeeze(original_images[i])
          semantic_prediction = np.squeeze(semantic_predictions[i])
          crop_semantic_prediction = semantic_prediction[:image_height, :image_width]

          save_dir='.'
          measure_traits(crop_semantic_prediction,
                      original_image,
                      save_dir,
                      image_names[i],
                      save_mask=${mask},
                      save_hull=${hull},
                      get_regionprops=True,
                      label_names=['background', 'rosette'],
                      channelstats=True)
          batch +=1 

      tf.compat.v1.logging.info(
        'Finished visualization at ' + time.strftime('%Y-%m-%d-%H:%M:%S',
                                                    time.gmtime()))
"""
}

results
 .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir)
