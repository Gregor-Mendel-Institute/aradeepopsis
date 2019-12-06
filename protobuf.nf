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
def format = imagetype == 'png' ?  'png' : 'jpeg'
"""
#!/usr/bin/env python

import time
import numpy as np

import tensorflow as tf

from traits import measure_traits

tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.INFO)

max_dim = ${dim}
crop_size_hw = [max_dim[1] + 1, max_dim[0] + 1]


#dat = tf.compat.v1.data.make_one_shot_iterator(dataset.repeat(1))

with tf.io.gfile.GFile('${baseDir}/model/multi.pb', "rb") as f:
    graph_def = tf.compat.v1.GraphDef()
    graph_def.ParseFromString(f.read())

with tf.Graph().as_default():
    #input = tf.compat.v1.placeholder(np.float32, shape=[1, 431, 439, 3], name="ImageTensor")
    tf.import_graph_def(graph_def, name='')

    def parse_record(record):
        features = {
            'image/encoded': tf.io.FixedLenFeature((), tf.string),
            'image/filename': tf.io.FixedLenFeature((), tf.string),
            'image/format': tf.io.FixedLenFeature((), tf.string),
            'image/height': tf.io.FixedLenFeature((), tf.int64),
            'image/width': tf.io.FixedLenFeature((), tf.int64),
            'image/channels': tf.io.FixedLenFeature((), tf.int64),
        }
        parsed = tf.io.parse_single_example(record, features)
        
        image = tf.image.decode_${format}(parsed['image/encoded'], 3)

        sample = {
        'image': image,
        'filename': parsed['image/filename'],
        }
        return sample

    dataset = (tf.data.TFRecordDataset('${shard}', num_parallel_reads=2)
            .map(parse_record))
    dataset = dataset.repeat(1)
    dataset = dataset.batch(1).prefetch(1)
    samples = tf.compat.v1.data.make_one_shot_iterator(dataset).get_next()
    
    #session = tf.compat.v1.Session()

    with tf.compat.v1.Session() as sess:
     #for data in samples:
     original_image = samples['image'].eval()
     image_name = samples['filename'].eval()
     #height = data['image/height']
     #width =  data['image/width']

     batchmap = sess.run('SemanticPredictions:0', feed_dict={'ImageTensor:0': original_image})
     crop_semantic_prediction = batchmap[0]

     #while not sess.should_stop():
     print('predicting')
     save_dir='.'
     measure_traits(crop_semantic_prediction,
                original_image,
                save_dir,
                image_name[0],
                save_mask=${mask},
                save_hull=${hull},
                get_regionprops=True,
                label_names=['background', 'rosette'],
                channelstats=True)

"""
}

results
 .collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir)
