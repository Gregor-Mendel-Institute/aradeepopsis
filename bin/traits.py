#!/usr/bin/env python

import csv
import numpy as np
import matplotlib.pyplot as plt

from skimage.measure import regionprops
from skimage.util import img_as_ubyte
from skimage.color import gray2rgb,label2rgb
from skimage.io import imsave
from skimage.morphology import convex_hull_image

def measure_traits(mask,
                   image,
                   file_name,
                   label_names=['background','rosette'],
                   save_rosette=True,
                   save_overlay=True,
                   save_histogram=True,
                   save_mask=True,
                   save_hull=True):
  """Calculates traits from plant rosette segmentations and optionally saves diagnostic images on disk.

  Args:
    label: The numpy array to be saved. The data will be converted
      to uint8 and saved as png image.
    image: Array representing the original image.
    file_name: String, the image filename.
    save_rosette: Boolean, save cropped rosette to disk.
    save_mask: Boolean, save the prediction to disk.
    save_overlay: Boolean, save the superimposed mask and image to disk.
    save_hull: Boolean, save the convex hull to disk.
    label_names: List, Names of labels
  """

  filename, filefmt = file_name.rsplit('.', 1)

  frame = {'file' : filename, 'format' : filefmt}

  # define color map
  green_leaf = [31,158,137]
  senescent_leaf = [253,231,37]
  antho_leaf = [72,40,120]

  colormap = np.array([green_leaf, senescent_leaf, antho_leaf])

  traits = ['filled_area',
            'convex_area',
            'equivalent_diameter',
            'major_axis_length',
            'minor_axis_length',
            'perimeter',
            'eccentricity',
            'extent',
            'solidity']
 
  image = img_as_ubyte(image)
  mask = img_as_ubyte(mask)

  crop = image * mask[...,None]

  for idx,band in enumerate(['red','green','blue']):
    channel = image[:,:,idx]
    frame[band + '_channel_mean'] = np.mean(channel[mask > 0])
    frame[band + '_channel_median'] = np.median(channel[mask > 0])

  # iterate over label names and count pixels for each class 
  for idx,labelclass in enumerate(label_names):
    count = np.count_nonzero(mask == idx)
    frame[labelclass] = count

  if save_histogram:
    plt.figure(figsize=(2,4))
    for idx,band in enumerate(['red','green','blue']):
        plt.plot(np.bincount(image[:,:,idx][mask > 0]),color=band)
    plt.axis('off')
    plt.text(0,-20,filename)
    plt.savefig('histogram_%s.png' % filename, bbox_inches='tight')
    plt.close()

  if save_rosette:
    imsave('crop_%s.png' % filename, crop)

  if save_mask:
    colored_mask = label2rgb(mask,colors=colormap,bg_label=0,kind='overlay')
    imsave('mask_%s.png' % filename, colored_mask)

  if save_overlay:
    colored = label2rgb(mask,image=image,bg_label=0,kind='overlay')
    imsave('overlay_%s.png' % filename, colored)

  if save_hull:
    hull = label2rgb(convex_hull_image(mask),image=image,bg_label=0,kind='overlay')
    imsave('convex_hull_%s.png' % filename, hull)

  # set senescent leaves to zero
  mask[mask == 2] = 0
  # merge green and anthocyanin classes for calculating region properties
  mask[mask > 0] = 1

  properties = regionprops(mask)
  for trait in traits:
    try:
      frame[trait] = properties[0][trait]
    except IndexError:
      frame[trait] = 'NA'

  # write pixel counts to tsv file
  with open('traits.csv', 'a') as counts:
    Writer = csv.DictWriter(counts, fieldnames=frame.keys(), dialect='unix', quoting=csv.QUOTE_NONE)
    if not counts.tell():
      Writer.writeheader()
    Writer.writerow(frame)

  return frame