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

process MODEL {
    tag "${params.model}"
    container "quay.io/beckerlab/aradeepopsis-base:${workflow.manifest.version}"

    input:
        path(model)
        tuple val(index), path(shard)
    output:
        tuple val(index), path('*.png'), emit: masks
    script:
        """
        #!/usr/bin/env python

        import logging

        import tensorflow as tf

        from data_record import parse_record
        from frozen_graph import wrap_frozen_graph

        logger = tf.get_logger()
        logger.propagate = False
        logger.setLevel('INFO')

        with tf.io.gfile.GFile('${model}', "rb") as f:
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
            raw_segmentation = predict(sample['original'])[0][:, :, None]
            output = tf.image.encode_png(tf.cast(raw_segmentation, tf.uint8))
            tf.io.write_file(filename.rsplit('.', 1)[0] + '.png',output)
        """
}