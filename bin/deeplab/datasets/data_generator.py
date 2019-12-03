# Lint as: python2, python3
# Copyright 2018 The TensorFlow Authors All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
"""Wrapper for providing semantic segmentation data.

The SegmentationDataset class provides both images and annotations (semantic
segmentation and/or instance segmentation) for TensorFlow.
"""

import collections
import os
import tensorflow as tf
from deeplab import common
from deeplab import input_preprocess

# Named tuple to describe the dataset properties.
DatasetDescriptor = collections.namedtuple(
    'DatasetDescriptor',
    [
        'splits_to_sizes',  # Splits of the dataset into training, val and test.
        'num_classes',  # Number of semantic classes, including the
                        # background class (if exists). For example, there
                        # are 20 foreground classes + 1 background class in
                        # the PASCAL VOC 2012 dataset. Thus, we set
                        # num_classes=21.
        'ignore_label',  # Ignore label value.
    ])

_ROSETTE_INFORMATION = DatasetDescriptor(
                    splits_to_sizes={'test': 100},
                    num_classes=3,
                    ignore_label=255,
		    )

_DATASETS_INFORMATION = {
    'rosettes': _ROSETTE_INFORMATION,
}

# Default file pattern of TFRecord of TensorFlow Example.
_FILE_PATTERN = 'chunk*'

class Dataset(object):
  """Represents input dataset for deeplab model."""

  def __init__(self,
               dataset_name,
               split_name,
               dataset_dir,
               batch_size,
               crop_size,
               min_resize_value=None,
               max_resize_value=None,
               resize_factor=None,
               min_scale_factor=1.,
               max_scale_factor=1.,
               scale_factor_step_size=0,
               model_variant=None,
               num_readers=2):
    """Initializes the dataset.

    Args:
      dataset_name: Dataset name.
      split_name: A train/val Split name.
      dataset_dir: The directory of the dataset sources.
      batch_size: Batch size.
      crop_size: The size used to crop the image and label.
      min_resize_value: Desired size of the smaller image side.
      max_resize_value: Maximum allowed size of the larger image side.
      resize_factor: Resized dimensions are multiple of factor plus one.
      min_scale_factor: Minimum scale factor value.
      max_scale_factor: Maximum scale factor value.
      scale_factor_step_size: The step size from min scale factor to max scale
        factor. The input is randomly scaled based on the value of
        (min_scale_factor, max_scale_factor, scale_factor_step_size).
      model_variant: Model variant (string) for choosing how to mean-subtract
        the images. See feature_extractor.network_map for supported model
        variants.
      num_readers: Number of readers for data provider.
      should_shuffle: Boolean, if should shuffle the input data.
      should_repeat: Boolean, if should repeat the input data.

    Raises:
      ValueError: Dataset name and split name are not supported.
    """
    if dataset_name not in _DATASETS_INFORMATION:
      raise ValueError('The specified dataset is not supported yet.')
    self.dataset_name = dataset_name

    splits_to_sizes = _DATASETS_INFORMATION[dataset_name].splits_to_sizes

    if split_name not in splits_to_sizes:
      raise ValueError('data split name %s not recognized' % split_name)

    if model_variant is None:
      tf.logging.warning('Please specify a model_variant. See '
                         'feature_extractor.network_map for supported model '
                         'variants.')

    self.split_name = split_name
    self.dataset_dir = dataset_dir
    self.batch_size = batch_size
    self.crop_size = crop_size
    self.min_resize_value = min_resize_value
    self.max_resize_value = max_resize_value
    self.resize_factor = resize_factor
    self.min_scale_factor = min_scale_factor
    self.max_scale_factor = max_scale_factor
    self.scale_factor_step_size = scale_factor_step_size
    self.model_variant = model_variant
    self.num_readers = num_readers

    self.num_of_classes = _DATASETS_INFORMATION[self.dataset_name].num_classes
    self.ignore_label = _DATASETS_INFORMATION[self.dataset_name].ignore_label

  def _parse_function(self, example_proto):
    """Function to parse the example proto.

    Args:
      example_proto: Proto in the format of tf.Example.

    Returns:
      A dictionary with parsed image, height, width and image name.
    """

    # Currently only supports jpeg and png.
    # Need to use this logic because the shape is not known for
    # tf.image.decode_image and we rely on this info to
    # extend label if necessary.
    def _decode_image(content, channels):
      return tf.cond(
          tf.image.is_jpeg(content),
          lambda: tf.image.decode_jpeg(content, channels),
          lambda: tf.image.decode_png(content, channels))

    features = {
        'image/encoded':
            tf.FixedLenFeature((), tf.string, default_value=''),
        'image/filename':
            tf.FixedLenFeature((), tf.string, default_value=''),
        'image/format':
            tf.FixedLenFeature((), tf.string, default_value='jpeg'),
        'image/height':
            tf.FixedLenFeature((), tf.int64, default_value=0),
        'image/width':
            tf.FixedLenFeature((), tf.int64, default_value=0),
    }

    parsed_features = tf.parse_single_example(example_proto, features)

    image = _decode_image(parsed_features['image/encoded'], channels=3)

    image_name = parsed_features['image/filename']

    sample = {
        common.IMAGE: image,
        common.IMAGE_NAME: image_name,
        common.HEIGHT: parsed_features['image/height'],
        common.WIDTH: parsed_features['image/width'],
    }
    return sample

  def _preprocess_image(self, sample):
    """Preprocesses the image.

    Args:
      sample: A Sample containing image.

    Returns:
      sample: Sample with preprocessed image.

    """
    image = sample[common.IMAGE]

    original_image, image = input_preprocess.preprocess_image(
        image=image,
        crop_height=self.crop_size[0],
        crop_width=self.crop_size[1],
        min_resize_value=self.min_resize_value,
        max_resize_value=self.max_resize_value,
        resize_factor=self.resize_factor,
        min_scale_factor=self.min_scale_factor,
        max_scale_factor=self.max_scale_factor,
        scale_factor_step_size=self.scale_factor_step_size,
        ignore_label=self.ignore_label,
        model_variant=self.model_variant)

    sample[common.IMAGE] = image

    sample[common.ORIGINAL_IMAGE] = original_image
    return sample

  def get_one_shot_iterator(self):
    """Gets an iterator that iterates across the dataset once.

    Returns:
      An iterator of type tf.data.Iterator.
    """

    files = self._get_all_files()

    dataset = (
        tf.data.TFRecordDataset(files, num_parallel_reads=self.num_readers)
        .map(self._parse_function, num_parallel_calls=self.num_readers)
        .map(self._preprocess_image, num_parallel_calls=self.num_readers))

    dataset = dataset.repeat(1)

    dataset = dataset.batch(self.batch_size).prefetch(self.batch_size)
    return dataset.make_one_shot_iterator()

  def _get_all_files(self):
    """Gets all the files to read data from.

    Returns:
      A list of input files.
    """
    file_pattern = 'chunk*'
    return tf.gfile.Glob(file_pattern)
