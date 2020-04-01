#!/usr/bin/env python

# Copyright (C) 2019-2020 Patrick Hüther
#
# This file is part of araDeepopsis.
# araDeepopsis free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# araDeepopsis is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with araDeepopsis.  If not, see <https://www.gnu.org/licenses/>.

import csv
import os
import numpy as np

from skimage.measure import regionprops
from skimage.io import imsave,imread,ImageCollection
from skimage.morphology import convex_hull_image
from skimage.transform import rescale

def measure_traits(mask,
                   image,
                   scale_ratio,
                   file_name,
                   ignore_senescence,
                   label_names):
  """Calculates traits from plant rosette segmentations.

  Args:
    mask: Array representing a segmentation mask.
    image: Array representing the original image.
    scale_ratio: Float, scale factor of the downscaled image.
    file_name: String, the image filename.
    ignore_senescence: Boolean, ignore senescence label for trait calculation.
    label_names: List, Names of labels.
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

  def _calculate_color_indices(channel_values, mask, labelname, ignore_senescence, value):
    """Calculates color channel indices within a segmented mask following Del Valle et al. (2018).

    Args:
      channel_values: Dict, contains 2D-arrays of red, green and blue channel intensities
      mask: Array representing a segmentation mask.
      labelname: String, name of label class.
      ignore_senescence: Boolean, ignore senescence label for trait calculation.
      value: Integer, pixel value of label class.
    Returns:
      Dictionary of values
    """
    stats = {}
    label_mask = create_bool_mask(mask, labelname, ignore_senescence, value)
    for channel,values in channels.items():
      stats[channel] = np.mean(values[label_mask])
    stats['chroma_ratio'] = stats['green_channel'] / ((stats['blue_channel'] + stats['red_channel']) / 2)
    stats['chroma_difference'] = ((stats['blue_channel'] + stats['red_channel']) / 2) - stats['green_channel']
    stats['chroma_base'] = (stats['blue_channel'] + stats['red_channel']) / stats['green_channel']
    stats['green_strength'] = stats['green_channel'] / (stats['red_channel'] + stats['green_channel'] + stats['blue_channel'])
    stats['blue_green_ratio'] = stats['blue_channel'] / stats['green_channel']

    return {f'{labelname}_{k}': v for k, v in stats.items()}

  def _calculate_morphometry(mask, labelname, value, scale_ratio, ignore_senescence):
    """Calculates morphometric traits using scikit-image.

    Args:
      mask: Array representing a segmentation mask.
      channel_values: Dict, contains 2D-arrays of red, green and blue channel intensities
      labelname: String, name of label class.
      value: Integer, pixel value of label class.
      scale_ratio: Float, scale factor of a previously downscaled image.
      ignore_senescence: Boolean, ignore senescence label for trait calculation.
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
      label_mask = create_bool_mask(mask, label, ignore_senescence, 2)
    else:
      label = labelname
      label_mask = create_bool_mask(mask, label, ignore_senescence, value)

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

  filename, filefmt = file_name.rsplit('.', 1)

  frame = {'file' : filename, 'format' : filefmt}

  # split image into red, green and blue channel
  channels = _split_channels(image)

  # get color channel information for whole plant region
  frame.update(_calculate_color_indices(channels, mask, 'plant_region', ignore_senescence, 2))

  for value,label in enumerate(label_names):
    # get morphometric traits
    frame.update(_calculate_morphometry(mask, label, value, scale_ratio, ignore_senescence))
    # get color channel information for each class except background
    if value == 0:
      continue
    frame.update(_calculate_color_indices(channels, mask, label, ignore_senescence, value))

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
                     ignore_senescence):
  """Saves diagnostic images to disk.

  Args:
    mask: Array representing the segmented mask
    image: Array representing the original image.
    file_name: String, the image filename.
    save_rosette: Boolean, save cropped rosette to disk.
    save_mask: Boolean, save the prediction to disk.
    save_overlay: Boolean, save the superimposed image and mask to disk.
    save_hull: Boolean, save the convex hull to disk.
    ignore_senescence: Boolean, ignore senescence label for convex hull calculation.
  """
  filename, filefmt = file_name.rsplit('.', 1)
  colormap = np.array([[0,0,0],[31,158,137],[253,231,37],[72,40,120]])

  colored_mask = colormap[mask]

  if save_rosette:
    crop = image * (mask > 0)[...,None]
    imsave('crop_%s.jpeg' % filename, crop.astype(np.uint8))

  if save_mask:
    imsave('mask_%s.png' % filename, colored_mask.astype(np.uint8))

  if save_overlay:
    overlay = 0.6 * image + 0.4 * colored_mask
    imsave('overlay_%s.jpeg' % filename, overlay.astype(np.uint8))

  if save_hull:
    bool_mask = create_bool_mask(mask, 'plant_region', ignore_senescence, 2)
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

def create_bool_mask(mask, label, ignore_senescence, value):
  """Creates a boolean mask for plant region or individual class.

  Args:
    mask: Array representing a mask with integer labels
    ignore_senescence: Boolean, whether to exclude senescent class label.
    value: Integer, pixel value to exclude.
    label: String, which label to return. 'plant_region' returns mask for whole plant.
  Returns:
    Array of type numpy.bool_
  """
  if label == 'plant_region':
    bool_mask = (mask > 0) if not ignore_senescence else (mask > 0) & (mask != value)
  else:
    bool_mask = (mask == value)

  return bool_mask
