process build_records {
    stageInMode 'copy'
    input:
        tuple val(index), path('images/*')
    output:
        tuple val(index), path('*.tfrecord'), emit: ch_shards
        tuple val(index), path('images/*', includeInputs: true), emit: ch_originals
        tuple val(index), path('ratios.p'), emit: ch_ratios
        path '*.txt', optional: true, emit: invalid_images
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