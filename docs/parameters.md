# Table of contents

* [Pipeline parameters](#main)
    * [`--model`](#--model)
    * [`--images`](#--images)
    * [`--multiscale`](#--multiscale)
    * [`--chunksize`](#--chunksize)
    * [`--ignore_senescence`](#--ignore_senescence)
    * [`--outdir`](#--outdir)
* [Pipeline diagnostics](#diagnostics)
    * [`--save_overlay`](#--save_overlay)
    * [`--save_mask`](#--save_mask)
    * [`--save_rosette`](#--save_rosette)
    * [`--save_hull`](#--save_hull)
    * [`--save_histogram`](#--save_histogram)
    * [`--summary_diagnostics`](#--summary_diagnostics)
    * [`--shiny`](#--shiny)

## --model <Integer>

The pretrained model that is used for image segmentation. Currently, there are 3 available models that will classify pixels based on the leaf classes they were trained on:

* `1`: trained on ground truth annotations for rosette leaves only
* `2`: trained on ground truth annotations for rosette and senescent leaves
* `3`: trained on ground truth annotations for rosette, anthocyanin-rich and senescent leaves

## --images <Path>

Path to the images to be analysed. Supported image formats include PNG and JPEG.

> Note that the path has to be enclosed in quotes and include a glob pattern that matches the images e.g. `--images '/path/to/images/*png'`

## --multiscale <Boolean>

Specifies whether the input image is scaled during model prediction. This yields higher accuracy at the cost of higher computational demand.

## --chunksize <Integer>

The number of images in each chunk, determining the degree of parallelization.
The smaller the chunksize, the more jobs will be spawned.

## --ignore_senescence <Boolean>

Ignore senescent class when calculating morphometric traits, focussing on living tissue only.

> Note that this only affects models `2` & `3` 

## --outdir <Integer>

The directory that results will be saved to.

## --save_overlay <Boolean>

Save overlays of the original images with the segmentation masks to the results directory.

## --save_mask <Boolean>

Save the segmentation masks to the results directory.

## --save_rosette <Boolean>

Save rosette images that were cropped to the region of interest to the results directory.

## --save_hull <Boolean>

Save convex hull images to the results directory.

## --summary_diagnostics <Boolean>

Merge individual overlays, masks and rosette images into larger summaries that allow for quick inspection of results.

## --shiny <Boolean>

Launch a [Shiny](https://shiny.rstudio.com/) app in the last step of the pipeline, allowing for interactive inspection of results. 

> Note that the app will run on the host where the main Nextflow process is running. If you are running the pipeline on a remote server, it has to expose port 44333 to the network.
