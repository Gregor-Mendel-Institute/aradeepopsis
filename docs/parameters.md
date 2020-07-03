# Table of contents

* [Pipeline parameters](#main)
    * [`--model`](#--model)
    * [`--images`](#--images)
    * [`--masks`](#--masks)
    * [`--multiscale`](#--multiscale)
    * [`--chunksize`](#--chunksize)
    * [`--ignore_senescence`](#--ignore_senescence)
    * [`--outdir`](#--outdir)
    * [`--save_overlay`](#--save_overlay)
    * [`--save_mask`](#--save_mask)
    * [`--save_rosette`](#--save_rosette)
    * [`--save_hull`](#--save_hull)
    * [`--summary_diagnostics`](#--summary_diagnostics)
    * [`--shiny`](#--shiny)

## --model

> Note that this parameter is ignored if `--masks` is set.

The pretrained model that is used for image segmentation. Currently, there are 3 available models that will classify pixels based on the leaf classes they were trained on:

* `A`: trained on ground truth annotations for ordinary leaves (class_norm) only
* `B`: trained on ground truth annotations for ordinary (class_norm) and senescent (class_senesc) leaves
* `C`: trained on ground truth annotations for ordinary (class_norm), and senescent (class_senesc) and anthocyanin-rich (class_antho) leaves

![Models](img/example_models.png)

## --images

Path to the images to be analysed. Supported image formats include PNG and JPEG.

> Note that the path has to be enclosed in quotes and include a glob pattern that matches the images e.g. `--images '/path/to/images/*png'`

## --masks

Path to segmentation masks corresponding to the images supplied with `--images`.
When this parameter is set, the pipeline will _not_ perform semantic segmentation using a trained model,
it will only extract morphometric traits based on the user-supplied masks.

> Note that the path has to be enclosed in quotes and include a glob pattern that matches the images e.g. `--masks '/path/to/masks/*png'`.
> The filenames and dimensions for each pair of mask and image have to match!

## --multiscale

> Note that this parameter is ignored if `--masks` is set.

Specifies whether the input image is scaled during model prediction. This yields higher accuracy at the cost of higher computational demand.

## --chunksize

The number of images in each chunk, determining the degree of parallelization.
The smaller the chunksize, the more jobs will be spawned.

## --ignore_senescence

> Note that this parameter only affects models `B` & `C` and will be ignored otherwise.

Ignore senescent class when calculating morphometric traits, focussing on living tissue only.

## --outdir

The directory that results will be saved to.

## --save_overlay

Save overlays of the original images with the segmentation masks to the results directory.

## --save_mask

Save the segmentation masks to the results directory.

## --save_rosette

Save rosette images that were cropped to the region of interest to the results directory.

## --save_hull

Save convex hull images to the results directory.

## --summary_diagnostics

Merge individual overlays, masks and rosette images into larger summaries that allow for quick inspection of results.

## --shiny

Launch a [Shiny](https://shiny.rstudio.com/) app in the last step of the pipeline, allowing for interactive inspection of results. 

> Note that the app will run on the host where the main Nextflow process is running.
> If you are running the pipeline on a remote server, it has to expose port 44333 to the network.
>
> If this is not the case, the shiny app can also be run manually on a local computer from the results directory.
> This has to happen from within the container or conda environment, respectively.
> ```bash
> # change to results directory (needs to be copied to local file system first)
> cd /path/to/results
>
> # if using the conda environment
> conda create -f /path/to/cloned/repository/environment.yml
> conda activate aradeepopsis
> R -e "shiny::runApp('app.R', port=44333)"
>
> # if using the container image
> {docker|podman} run -v $(pwd):/mnt/shiny -p 44333:44333 beckerlab/aradeepopsis:dev R -e "shiny::runApp('/mnt/shiny/app.R', port=44333, host='0.0.0.0')"
> ```
> The shiny app can then be opened with a browser by typing localhost:44333 in the address bar. It will terminate when the browser window is closed.
