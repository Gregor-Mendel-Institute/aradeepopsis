#!/usr/bin/env python

import csv
import os
import numpy as np
import matplotlib.pyplot as plt

from skimage.measure import regionprops
from skimage.io import imsave,imread,ImageCollection
from skimage.morphology import convex_hull_image

def measure_traits(mask,
                   image,
                   file_name,
                   label_names=['background','rosette']):
  """Calculates traits from plant rosette segmentations.

  Args:
    mask: Array representing the segmented mask.
    image: Array representing the original image.
    file_name: String, the image filename.
    label_names: List, Names of labels
  """
  filename, filefmt = file_name.rsplit('.', 1)

  frame = {'file' : filename, 'format' : filefmt}

  traits = ['filled_area',
            'convex_area',
            'equivalent_diameter',
            'major_axis_length',
            'minor_axis_length',
            'perimeter',
            'eccentricity',
            'extent',
            'solidity']

  # iterate over label names and count pixels for each class 
  for idx,labelclass in enumerate(label_names):
    count = np.count_nonzero(mask == idx)
    frame[labelclass] = count

  for idx,band in enumerate(['red','green','blue']):
    channel = image[:,:,idx]
    frame[band + '_channel_mean'] = np.mean(channel[mask > 0])
    frame[band + '_channel_median'] = np.median(channel[mask > 0])

  # only consider non-senescent leaves for calculating region properties
  merged = (mask > 0) & (mask != 2)

  properties = regionprops(merged.astype(np.uint8))
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

def draw_diagnostics(mask,
                     image,
                     file_name,
                     save_rosette=True,
                     save_overlay=True,
                     save_histogram=True,
                     save_mask=True,
                     save_hull=True):
  """Saves diagnostic images to disk.

  Args:
    mask: Array representing the segmented mask
    image: Array representing the original image.
    file_name: String, the image filename.
    save_rosette: Boolean, save cropped rosette to disk.
    save_mask: Boolean, save the prediction to disk.
    save_overlay: Boolean, save the superimposed image and mask to disk.
    save_hull: Boolean, save the convex hull to disk.
  """
  filename, filefmt = file_name.rsplit('.', 1)
  colormap = np.array([[0,0,0],[31,158,137],[253,231,37],[72,40,120]])

  colored_mask = colormap[mask]

  if save_histogram:
    os.makedirs('histogram', exist_ok=True)
    plt.figure(figsize=(2,4))
    for idx,band in enumerate(['red','green','blue']):
        plt.plot(np.bincount(image[:,:,idx][mask > 0]),color=band)
    plt.axis('off')
    plt.text(0,-20,filename)
    plt.savefig('histogram/%s.png' % filename, bbox_inches='tight')
    plt.close()

  if save_rosette:
    os.makedirs('crop', exist_ok=True)
    crop = image * (mask > 0)[...,None]
    imsave('crop/%s.png' % filename, crop.astype(np.uint8))

  if save_mask:
    os.makedirs('mask', exist_ok=True)
    imsave('mask/%s.png' % filename, colored_mask.astype(np.uint8))

  if save_overlay:
    os.makedirs('overlay', exist_ok=True)
    overlay = 0.4 * image + 0.6 * colored_mask
    imsave('overlay/%s.png' % filename, overlay.astype(np.uint8))

  if save_hull:
    os.makedirs('convex_hull', exist_ok=True)
    hull = convex_hull_image(mask)*255
    imsave('convex_hull/%s.png' % filename, hull.astype(np.uint8))

def load_images():
  def _loader(f):
    return imread(f).astype(np.uint8)
  masks = ImageCollection('raw_masks/*',load_func=_loader)
  originals = ['original_images/' + os.path.basename(i).rsplit('.', 1)[0] + '.*' for i in masks.files]
  originals = ImageCollection(originals,load_func=_loader)
  return masks, originals