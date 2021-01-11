#!/usr/bin/env python

# Copyright (C) 2019-2020 Patrick Hüther
#
# This file is part of ARADEEPOPSIS.
# ARADEEPOPSIS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ARADEEPOPSIS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ARADEEPOPSIS.  If not, see <https://www.gnu.org/licenses/>.

import csv
import os
import numpy as np

from skimage.measure import regionprops
from skimage.io import imsave, imread, ImageCollection
from skimage.morphology import convex_hull_image
from skimage.transform import rescale

def measure_traits(mask,
                   image,
                   scale_ratio,
                   file_name,
                   ignore_label,
                   labels):
  """Calculates traits from plant rosette segmentations.

  Args:
    mask: Array representing a segmentation mask.
    image: Array representing the original image.
    scale_ratio: Float, scale factor of the downscaled image.
    file_name: String, the image filename.
    ignore_label: Integer, pixel value of label to ignore for trait calculation.
    labels: Dict, Key=value pairs of labelname and (grayscale) pixel value.
  """
  def _split_channels(image):
    """Splits an RGB image into single channels.

    Args:
      image: Array representing an RGB image
    Returns:
      Dictionary of color channel arrays
    """
    red = image[:,:,0].astype(np.uint8)
    green = image[:,:,1].astype(np.uint8)
    blue = image[:,:,2].astype(np.uint8)

    return {'red_channel':red,'green_channel':green,'blue_channel':blue}

  def _check_mask_dimensions(image, mask, filename):
    """Validates image and corresponding mask dimensions. Raises error in case of mismatch.

    Args:
      image: Array representing an RGB image
      mask: Array representing a segmentation mask
    """
    if len(mask.shape) > 2:
      raise SystemExit(f'ERROR: Mask {filename} appears to contain color channels, only grayscale masks are supported!')
    elif image.shape[:2] != mask.shape:
      raise SystemExit(f'ERROR: Could not process image {filename}. Dimensions of image and mask have to match!')

  def _calculate_color_indices(channel_values, mask, label_name, ignore_label):
    """Calculates color channel indices within a segmented mask following Del Valle et al. (2018).

    Args:
      channel_values: Dict, contains 2D-arrays of red, green and blue channel intensities
      mask: Array representing a segmentation mask.
      label_name: String, name of label class.
      ignore_label: Integer, pixel value of label to ignore for trait calculation.
      value: Integer, pixel value of label class.
    Returns:
      Dictionary of values
    """
    stats = {}
    label_mask = create_bool_mask(mask, label_name, ignore_label)
    for channel,values in channels.items():
      stats[channel] = np.mean(values[label_mask])
    stats['chroma_ratio'] = stats['green_channel'] / ((stats['blue_channel'] + stats['red_channel']) / 2)
    stats['chroma_difference'] = ((stats['blue_channel'] + stats['red_channel']) / 2) - stats['green_channel']
    stats['chroma_base'] = (stats['blue_channel'] + stats['red_channel']) / stats['green_channel']
    stats['green_strength'] = stats['green_channel'] / (stats['red_channel'] + stats['green_channel'] + stats['blue_channel'])
    stats['blue_green_ratio'] = stats['blue_channel'] / stats['green_channel']

    return {f'{label_name}_{k}': v for k, v in stats.items()}

  def _calculate_morphometry(mask, label_name, value, scale_ratio, ignore_label):
    """Calculates morphometric traits using scikit-image.

    Args:
      mask: Array representing a segmentation mask.
      channel_values: Dict, contains 2D-arrays of red, green and blue channel intensities
      label_name: String, name of label class.
      value: Integer, pixel value of label class.
      scale_ratio: Float, scale factor of a previously downscaled image.
      ignore_label: Integer, pixel value of label to ignore for trait calculation.
    Returns:
      Dictionary of values
    """
    traits = {}
    traitlist = ['area',
                 'filled_area',
                 'convex_area',
                 'equivalent_diameter',
                 'major_axis_length',
                 'minor_axis_length',
                 'perimeter',
                 'eccentricity',
                 'extent',
                 'solidity']

    # scale the mask up to the dimensions of the original image if it was downscaled
    if scale_ratio != 1.0:
      mask = rescale(mask, scale_ratio, preserve_range=True, anti_aliasing=False, order=0)

    if value == 0:
      traits['total_area'] = mask.size
      traits['class_background_area'] = np.count_nonzero(mask == value)
      label = 'plant_region'
      label_mask = create_bool_mask(mask, label, ignore_label)
    else:
      label = label_name
      label_mask = create_bool_mask(mask, label, value)

    properties = regionprops(label_mask.astype(np.uint8))
    for trait in traitlist:
      try:
        traits[f'{label}_{trait}'] = properties[0][trait]
      except (IndexError, ValueError):
        traits[f'{label}_{trait}'] = 0 if 'area' in trait else np.nan
    try:
      traits[f'{label}_aspect_ratio'] = traits[f'{label}_major_axis_length'] / traits[f'{label}_minor_axis_length']
    except ZeroDivisionError:
      traits[f'{label}_aspect_ratio'] = np.nan

    return traits

  _check_mask_dimensions(image, mask, file_name)

  filename, filefmt = file_name.rsplit('.', 1)

  frame = {'file' : filename, 'format' : filefmt}

  # split image into red, green and blue channel
  channels = _split_channels(image)

  # get color channel information for whole plant region
  frame.update(_calculate_color_indices(channels, mask, 'plant_region', ignore_label))

  for label, value in labels.items():
    # get morphometric traits
    frame.update(_calculate_morphometry(mask, label, value, scale_ratio, ignore_label))
    # get color channel information for each class except background
    if value == 0:
      continue
    frame.update(_calculate_color_indices(channels, mask, label, value))

  # write pixel counts to csv file
  with open('traits.csv', 'a') as counts:
    Writer = csv.DictWriter(counts, fieldnames=frame.keys(), dialect='unix', quoting=csv.QUOTE_NONE)
    if not counts.tell():
      Writer.writeheader()
    Writer.writerow(frame)

def draw_diagnostics(mask,
                     image,
                     file_name,
                     save_rosette,
                     save_overlay,
                     save_mask,
                     save_hull,
                     ignore_label,
                     labels,
                     colormap=None):
  """Saves diagnostic images to disk.

  Args:
    mask: Array representing the segmented mask
    image: Array representing the original image.
    file_name: String, the image filename.
    save_rosette: Boolean, save cropped rosette to disk.
    save_mask: Boolean, save the prediction to disk.
    save_overlay: Boolean, save the superimposed image and mask to disk.
    save_hull: Boolean, save the convex hull to disk.
    ignore_label: Integer, pixel value of label to ignore for trait calculation.
    labels: Dict, Key=value pairs of labelname and (grayscale) pixel value.
    colormap: List, RGB colormap to use for visualization.
  """
  filename, filefmt = file_name.rsplit('.', 1)

  if isinstance(colormap, list):
    cmap = np.array(colormap)
    if cmap.sum() == 2236:
      np.random.shuffle(cmap)
  else:
    # fallback to default
    cmap = np.array([[0,0,0],[31,158,137],[253,231,37],[72,40,120]])

  if len(labels) < max(labels.values()):
    for l, v in enumerate(labels.values()):
      mask[mask == v] = l

  colored_mask = cmap[mask]

  if save_rosette:
    crop = image[:,:,:3] * (mask > 0)[...,None]
    imsave('crop_%s.jpeg' % filename, crop.astype(np.uint8))

  if save_mask:
    imsave('mask_%s.png' % filename, colored_mask.astype(np.uint8))

  if save_overlay:
    overlay = 0.6 * image[:,:,:3] + 0.4 * colored_mask
    imsave('overlay_%s.jpeg' % filename, overlay.astype(np.uint8))

  if save_hull:
    bool_mask = create_bool_mask(mask, 'plant_region', ignore_label)
    hull = convex_hull_image(bool_mask)*255
    convex_hull = 0.6 * colored_mask + 0.4 * np.stack((hull,)*3, axis=-1)
    imsave('hull_%s.png' % filename, convex_hull.astype(np.uint8))

def load_images():
  """Loads ImageCollection into memory
  Returns:
    Two instances of skimage.io.ImageCollection
  """
  def _loader(f):
    return imread(f).astype(np.uint8)

  masks = ImageCollection('raw_masks/*',load_func=_loader)
  originals = ['original_images/' + os.path.basename(i).rsplit('.', 1)[0] + '.*' for i in masks.files]
  originals = ImageCollection(originals,load_func=_loader)

  return masks, originals

def create_bool_mask(mask, label, ignore_label):
  """Creates a boolean mask for plant region or individual class.

  Args:
    mask: Array representing a mask with integer labels
    ignore_label: Integer, pixel value of label to exclude.
    label: String, which label to return. 'plant_region' returns mask for whole plant.
  Returns:
    Array of type numpy.bool_
  """
  if label == 'plant_region':
    bool_mask = (mask > 0) if ignore_label is None else (mask > 0) & (mask != ignore_label)
  else:
    bool_mask = (mask == ignore_label)

  return bool_mask
