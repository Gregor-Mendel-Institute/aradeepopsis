#!/usr/bin/env python

import csv
import numpy as np
from PIL import Image,ImageStat

import tensorflow as tf
from skimage.measure import regionprops
from skimage.morphology import convex_hull_image

def measure_traits(mask,
                   image,
                   file_name,
                   get_regionprops=False,
                   channelstats=False,
                   label_names=['background', 'rosette'],
                   save_mask=False,
                   save_hull=False):
  """Counts pixels of all classes and optionally saves the given label to image on disk.

  Args:
    label: The numpy array to be saved. The data will be converted
      to uint8 and saved as png image.
    image: Array representing the original image.
    file_name: String, the image filename.
    save_prediction: Boolean, save the resulting prediction to disk.
    get_regionprops: Boolean, calculate various region properties (see: https://scikit-image.org/docs/dev/api/skimage.measure.html#skimage.measure.regionprops).
    channelstats: Boolean, calculate channel means in original image within the label mask.
    label_names: List, Names of labels
  """

  filename = file_name.rsplit('.', 1)[0]

  frame = {'file' : filename, 'total_pixels' : mask.size}

  # iterate over label names and count pixels for each class 
  for idx,labelclass in enumerate(np.asarray(label_names)):
    count = np.count_nonzero(mask == idx)
    frame[labelclass] = count

  if channelstats:
    org = Image.fromarray(image.astype(dtype=np.uint8))
    pred = Image.fromarray(mask.astype(dtype=np.uint8))
    stat = ImageStat.Stat(org, mask=pred)

    bands = np.asarray(['red', 'green','blue'])
    for idx,band in enumerate(bands):
      frame[band + "_sum_within_mask"] = stat.sum[idx]
      if stat.count[idx] != 0:
        frame[band + "_mean_within_mask"] = stat.mean[idx]
      else:
        frame[band + "_mean_within_mask"] = 'NA'
      frame[band + "_median_within_mask"] = stat.median[idx]
    
  if get_regionprops:
    traits = np.asarray(['filled_area','convex_area',"equivalent_diameter","major_axis_length","minor_axis_length","perimeter","eccentricity","extent","solidity"])
    properties = regionprops(mask)
    for trait in traits:
      if len(properties) == 1:
        frame[trait] = properties[0][trait]
      else:
        frame[trait] = 'NA'

  mask_dimensions = np.zeros(mask.shape)

  if save_mask:
    colored_mask = np.stack((mask * 255, mask_dimensions, mask_dimensions), axis=2)
    mask_image = Image.fromarray(colored_mask.astype(dtype=np.uint8))
    with tf.io.gfile.GFile('mask_%s.png' % (filename), mode='w') as m:
      mask_image.save(m, 'PNG')

  if save_hull:
    colored_hull = np.stack((convex_hull_image(mask) * 255, mask_dimensions, mask_dimensions), axis=2)
    hull_image = Image.fromarray(colored_hull.astype(dtype=np.uint8))
    with tf.gfile.Open('convex_hull_%s.png' % (filename), mode='w') as h:
      hull_image.save(h, 'PNG')

  # write pixel counts to tsv file
  with open('traits.csv', 'a') as counts:
    Writer = csv.DictWriter(counts, fieldnames=frame.keys())
    if not counts.tell():
      Writer.writeheader()
    Writer.writerow(frame)

  return frame
