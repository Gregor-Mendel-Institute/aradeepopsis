/*
Copyright (C) 2019-2022 Patrick Hüther

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

process RECORDS {
    container "quay.io/beckerlab/aradeepopsis-base:${workflow.manifest.version}"
    stageInMode 'copy'
   
    input:
        tuple val(index), path('images/*')
    output:
        tuple val(index), path('*.tfrecord'), emit: shards
        tuple val(index), path('images/*', includeInputs: true), path('ratios.p'), emit: originals
        path('*.txt'), optional: true, emit: invalid_images
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
                ratio = 1.0

                if height * width > ${params.size}**2:
                    logger.info('%s: dimensions %d x %d are too large,' % (filename, height, width))
                    ratio = max(height,width)/${params.size}
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