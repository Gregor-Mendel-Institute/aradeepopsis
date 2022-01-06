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

process DPP {
    container "quay.io/beckerlab/aradeepopsis-dpp:${workflow.manifest.version}"
    
    input:
        path("vegetation-segmentation/*")
        tuple val(index), path(shard)
    output:
        tuple val(index), path('*.png'), emit: masks
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
                img = tf.image.per_image_standardization(img)
                raw = pretrainedDPP.model.forward_pass(img, deterministic=True)
                try:
                    while True:
                        prediction, name = pretrainedDPP.model._session.run([raw,filename])
                        logger.info("Running prediction on image %s" % name)
                        mask = (np.squeeze(prediction) >= 0.5)
                        name = name[0].decode('utf-8').rsplit('.', 1)[0]
                        imwrite(f'{name}.png', mask.astype(np.uint8))
                except tf.errors.OutOfRangeError:
                    pass
        """
}