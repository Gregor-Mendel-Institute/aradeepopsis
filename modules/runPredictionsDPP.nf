process run_predictions_DPP {
    input:
        path("vegetation-segmentation/*")
        tuple val(index), path(shard)
    output:
        tuple val(index), path('*.png'), emit: ch_predictions
    script:
        """
        #!/usr/bin/env python

        import logging

        import numpy as np
        import tensorflow as tf
        import deepplantphenomics as dpp

        from cv2 import imwrite
        from data_record import parse_record

        logger = tf.get_logger()
        logger.propagate = False
        logger.setLevel('INFO')

        pretrainedDPP = dpp.networks.vegetationSegmentationNetwork(8)

        def checkpoint_override(net, checkpoint_path, num_classes):
            if num_classes != 2:
                net.model.set_num_segmentation_classes(num_classes)
            net.model._add_layers_to_graph()
            saver = tf.compat.v1.train.Saver()
            saver.restore(net.model._session, tf.train.latest_checkpoint(checkpoint_path))

        with pretrainedDPP.model._graph.as_default():
            checkpoint_override(pretrainedDPP,'vegetation-segmentation/', 2)
            dataset = (
            tf.data.TFRecordDataset('${shard}')
            .map(parse_record)
            .batch(1)
            .prefetch(1))

            samples = tf.compat.v1.data.make_one_shot_iterator(dataset).get_next()

            for i in samples:
                img, filename = tf.cast(samples['original'],tf.float32),  samples['filename']
                raw = pretrainedDPP.model.forward_pass(img, deterministic=True)
                try:
                    while True:
                        prediction, name = pretrainedDPP.model._session.run([raw,filename])
                        logger.info("Running prediction on image %s" % name)
                        seg = np.interp(prediction, (prediction.min(), prediction.max()), (0, 1))
                        mask = (np.squeeze(seg) > 0.5).astype(np.uint8)
                        name = name[0].decode('utf-8').rsplit('.', 1)[0]
                        imwrite(f'{name}.png', mask)
                except tf.errors.OutOfRangeError:
                    pass
        """
}