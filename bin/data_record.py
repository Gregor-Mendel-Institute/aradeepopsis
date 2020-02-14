#!/usr/bin/env python

import tensorflow as tf

def create_record(image_data, filename, height, width, ratio, channels, mask=''):
    def _bytes_feature(value):
        if isinstance(value, str):
            value = value.encode()
        return tf.train.Feature(bytes_list=tf.train.BytesList(value=[value]))

    def _int64_feature(value):
      return tf.train.Feature(int64_list=tf.train.Int64List(value=[value]))

    def _float_feature(value):
        return tf.train.Feature(float_list=tf.train.FloatList(value=[value]))

    features = {
        'image/original': _bytes_feature(image_data),
        'image/filename': _bytes_feature(filename),
        'image/height': _int64_feature(height),
        'image/width': _int64_feature(width),
        'image/resize_ratio': _float_feature(ratio),
        'image/channels': _int64_feature(channels),
        'image/mask': _bytes_feature(mask)
        }

#    if mask is not None:
#        features.update( {'image/mask': _bytes_feature(mask)} )

    sample = tf.train.Example(features=tf.train.Features(feature=features))
    return sample

def parse_record(record):
    features = {
        'image/original': tf.io.FixedLenFeature((), tf.string),
        'image/filename': tf.io.FixedLenFeature((), tf.string),
        'image/height': tf.io.FixedLenFeature((), tf.int64),
        'image/width': tf.io.FixedLenFeature((), tf.int64),
        'image/resize_ratio': tf.io.FixedLenFeature((), tf.float32),
        'image/channels': tf.io.FixedLenFeature((), tf.int64),
        'image/mask': tf.io.FixedLenFeature((), tf.string, default_value=''),
        }

    parsed = tf.io.parse_single_example(record, features)
    
    image = tf.io.decode_image(parsed['image/original'], channels=3, expand_animations=False)
    #image = parsed['image/original']
    name = parsed['image/filename']

    sample = {
    'original': image,
    'filename': parsed['image/filename'],
    'height': parsed['image/height'],
    'width': parsed['image/width'],
    'resize_factor': parsed['image/resize_ratio'],
    }

    try:
        mask = tf.io.decode_image(parsed['image/mask'], channels=1, expand_animations=False)
        sample.update( {'mask': mask} )
    except tf.errors.InvalidArgumentError:
        print('record does not contain a mask')

    return sample