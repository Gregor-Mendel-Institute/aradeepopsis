#!/usr/bin/env python

import tensorflow as tf
import imghdr

def create_record(image_data, file_names, height, width, channels):
    def _bytes_feature(value):
        if isinstance(value, str):
            value = value.encode()
        return tf.train.Feature(bytes_list=tf.train.BytesList(value=[value]))

    def _int64_feature(value):
      return tf.train.Feature(int64_list=tf.train.Int64List(value=[value]))

    image_format = imghdr.what('',image_data)

    features= {
        'image/encoded': _bytes_feature(image_data),
        'image/filename': _bytes_feature(file_names),
        'image/format': _bytes_feature(image_format),
        'image/height': _int64_feature(height),
        'image/width': _int64_feature(width),
        'image/channels': _int64_feature(channels),
        }
    
    sample = tf.train.Example(features=tf.train.Features(feature=features))
    return sample

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
    
    image = tf.io.decode_image(parsed['image/encoded'], channels=3, expand_animations=False)

    name = parsed['image/filename']

    sample = {
    'image': image,
    'filename': parsed['image/filename']
    }
    return sample