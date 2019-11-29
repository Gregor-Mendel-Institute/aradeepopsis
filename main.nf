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

params.chunksize = 5
params.imageformat = 'png'

Channel
    .fromPath(params.images, checkIfExists: true)
    .tap {ch_images}
    .collectFile() { item -> [ "list.txt", item.baseName + '\n' ] }
    .set {ch_list}

process build_TFRecords {
    publishDir "${params.outdir}/shards", mode: 'copy'
    input:
        file(images) from ch_images.collect()
        file(list) from ch_list
    output:
        file('*.tfrecord') into shards mode flatten

    script:
"""
#!/usr/bin/env python
import math
import os.path

import tensorflow as tf

with tf.Graph().as_default():
    decode_data = tf.placeholder(dtype=tf.string)
    image_format = ${params.imageformat}
    channels = 3
    session = tf.Session()

    if image_format in ('jpeg', 'jpg'):
        decode = tf.image.decode_jpeg(decode_data,
                                        channels=channels)
    elif image_format == 'png':
        decode = tf.image.decode_png(decode_data,
                                        channels=channels)

filenames = [x.strip('\n') for x in open(${list}, 'r')]
num_images = ${images.size()}
num_per_shard = int(math.ceil(num_images / float(${params.chunksize})))

for shard_id in range(${params.chunksize}):
    image = session.run(decode, feed_dict={decode_data: image_data})
    output_filename = '%05d-of-%05d.tfrecord'.format(shard_id, ${params.chunksize})
    with tf.python_io.TFRecordWriter(output_filename) as tfrecord_writer:
    start_idx = shard_id * num_per_shard
    end_idx = min((shard_id + 1) * num_per_shard, num_images)
    for i in range(start_idx, end_idx):
        sys.stdout.write('\r>> Converting image %d/%d shard %d' % (
            i + 1, len(filenames), shard_id))
        sys.stdout.flush()
        # Read the image.
        image_filename = filenames[i]
        image_data = tf.gfile.FastGFile(image_filename, 'rb').read()
        height, width = image.shape[:2]

        example = tf.train.Example(features=tf.train.Features(feature={
                                    'image/encoded': _bytes_list_feature(image_data),
                                    'image/filename': _bytes_list_feature(filenames[i]),
                                    'image/format': _bytes_list_feature(image_format),
                                    'image/height': _int64_list_feature(height),
                                    'image/width': _int64_list_feature(width),
                                    'image/channels': _int64_list_feature(3),
                                    }))
        tfrecord_writer.write(example.SerializeToString())
    sys.stdout.write('\n')
    sys.stdout.flush()
"""
}