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

params.chunksize = 100
params.imageformat = 'png'
params.crop_width = 600
params.crop_height = 600
params.gpu = false

Channel
    .fromPath(params.images, checkIfExists: true)
    .buffer(size:params.chunksize, remainder: true)
    .set {ch_images}

process build_TFRecords {
    publishDir "${params.outdir}/shards", mode: 'copy'
    input:
        file(images) from ch_images
    output:
        file('*.tfrecord') into ch_shards

    script:
//def cuda = params.gpu ? "os.environ['CUDA_VISIBLE_DEVICES']='-1'" : ''
"""
#!/usr/bin/env python

import tensorflow as tf

with tf.Graph().as_default():
    decode_data = tf.compat.v1.placeholder(dtype=tf.string)
    image_format = '${params.imageformat}'
    session = tf.compat.v1.Session()

    if image_format in ('jpeg', 'jpg'):
        decode = tf.image.decode_jpeg(decode_data, channels=3)
    elif image_format == 'png':
        decode = tf.image.decode_png(decode_data, channels=3)

filenames = tf.io.gfile.glob('*${params.imageformat}')

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
                                        'image/format': _bytes_feature(image_format),
                                        'image/height': _int64_feature(height),
                                        'image/width': _int64_feature(width),
                                        'image/channels': _int64_feature(3),
                                        }))
    tfrecord_writer.write(example.SerializeToString())
"""
}
