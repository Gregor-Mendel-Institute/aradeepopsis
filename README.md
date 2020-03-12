![](https://github.com/Gregor-Mendel-Institute/aradeepopsis/workflows/Integration%20test/badge.svg?branch=master)
[![Docker](https://github.com/Gregor-Mendel-Institute/aradeepopsis/workflows/Docker%20build/badge.svg)](https://hub.docker.com/r/beckerlab/aradeepopsis/)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A520.01.0-important.svg)](https://www.nextflow.io/)
[![conda](https://img.shields.io/badge/install%20with-conda-brightgreen.svg)](https://conda.io/)

# Introduction

ara*deep*opsis is a software tool that enables plant researchers to non-invasively score plant growth, biomass accumulation and senescence from image data in a highly parallelized, high throughput, yet easy to use manner.

It is built upon the published, convolutional neural network (CNN) [DeepLabv3+](https://github.com/tensorflow/models/tree/master/research/deeplab)<sup>[[1]](#ref1)</sup> that serves the task of semantic image segmentation. A [pretrained checkpoint](http://download.tensorflow.org/models/deeplabv3_xception_2018_01_04.tar.gz) of this model has been trained upon using manually annotated top-view images of *Arabidopsis thaliana* plants of different ages.

# How it works

The pipeline is implemented using open source technology such as [`Nextflow`](https://www.nextflow.io/)<sup>[[2]](#ref2)</sup>, [`TensorFlow`](https://www.tensorflow.org/)<sup>[[3]](#ref3)</sup>, [`ImageMagick`](https://imagemagick.org), [`scikit-image`](https://scikit-image.org/)<sup>[[4]](#ref4)</sup> and [`shiny`](https://shiny.rstudio.com/)<sup>[[5]](#ref5)</sup>.

Once the pipeline is fed with images of single plants, it converts the images into chunks of arbitrary size by saving the image data into an [IO-optimized binary file format](https://www.tensorflow.org/tutorials/load_data/tfrecord). These file records are then, in parallel, served to the deep learning model, allowing for pixel-by-pixel classification of the image data. The pipeline in turn extracts relevant phenotypic information such as:

* plant area
* degree of senescence and anthocyanin accumulation
* color composition
* a variety of morphometric traits that are informative about growth performance and behaviour

The pipeline uses either a [conda environment](https://conda.io/en/latest/) or a [Docker container](https://www.docker.com/resources/what-container) to resolve dependencies, ensuring a high level of reproducibility and portability. It is largely platform independent and scales from Personal Computers to High Performance Computing (HPC) infrastructure, allowing for time efficient analysis of hundreds of thousands of images within a day.

# Usage

## Setting up the pipeline

1. Install [`Nextflow`](https://www.nextflow.io/index.html#GetStarted)

2. Install either [`conda`](https://docs.conda.io/projects/conda/en/latest/user-guide/install/), [`Docker`](https://docs.docker.com/install/) (recommended), [`podman`](https://podman.io/getting-started/installation) or [`Singularity`](https://sylabs.io/guides/3.0/user-guide/installation.html)

3. Clone the repository: `git clone https://github.com/Gregor-Mendel-Institute/aradeepopsis`

## Running the pipeline

To run the pipeline you have to provide single-pot plant images:

```bash
nextflow /path/to/main.nf --images 'path/to/images/*{png|jpg}' -profile {conda|docker|podman|singularity}
```

### Example to run on the CBE cluster using Singularity

```bash
module load singularity/3.4.1
module load nextflow/19.10.0

nextflow /path/to/main.nf --images 'path/to/images/*{png|jpg}' -profile cbe,singularity
```

## Additional parameters

* `--model`: number of leaf classes to score. `default: 3`
    * `1` (rosette leaf)
    * `2` (rosette leaf, senescent leaf)
    * `3` (rosette leaf, senescent leaf, anthocyanin-rich leaf)
* `--ignore_senescence`: ignore senescent leaf class for trait calculation when using model `2` and `3`. `default: true`
* `--multiscale`: run multiscale inference which is slower but more accurate. `default: false`
* `--outdir`: output path. `default: ./results`
* `--chunksize`: number of images to process in per chunk. `default: 10`
* `--save_overlay`: save a diagnostic image with the original image overlayed with the predicted mask. `default: true`
* `--save_mask`: save the predicted mask to the output folder. `default: true`
* `--save_rosette`: save the original image cropped to the predicted mask to the output folder. `default: true`
* `--save_hull`: save the convex hull of the predicted mask to the output folder. `default: true`
* `--save_histogram`: save a color channel histogram of the cropped plant to the output folder. `default: false`
* `--summary_diagnostics`: draw combined diagnostic images for each chunk. `default: false`
* `--shiny`: launch shiny app after analysis has completed. `default: true`

# References

> <a name="ref1">[1]</a> **Encoder-Decoder with Atrous Separable Convolution for Semantic Image Segmentation.**<br />Chen, L.-C. et al., 2018. arXiv [cs.CV]. Available at: http://arxiv.org/abs/1802.02611.

> <a name="ref2">[2]</a> **Nextflow enables reproducible computational workflows.**<br />Di Tommaso, P. et al., 2017. Nature biotechnology, 35(4), pp.316–319.

> <a name="ref3">[3]</a> **TensorFlow: Large-scale machine learning on heterogeneous systems.**<br />Martín Abadi, Ashish Agarwal, Paul Barham, Eugene Brevdo, Zhifeng Chen, Craig Citro, Greg S. Corrado, Andy Davis, Jeffrey Dean, Matthieu Devin, Sanjay Ghemawat, Ian Goodfellow, Andrew Harp, Geoffrey Irving, Michael Isard, Rafal Jozefowicz, Yangqing Jia,Lukasz Kaiser, Manjunath Kudlur, Josh Levenberg, Dan Mané, Mike Schuster, Rajat Monga, Sherry Moore, Derek Murray, Chris Olah, Jonathon Shlens, Benoit Steiner, Ilya Sutskever, Kunal Talwar, Paul Tucker, Vincent Vanhoucke, Vijay Vasudevan, Fernanda Viégas, Oriol Vinyals, Pete Warden, Martin Wattenberg, Martin Wicke, Yuan Yu, and Xiaoqiang Zheng, 2015

> <a name="ref4">[4]</a> **scikit-image: Image processing in Python.**<br />Stéfan van der Walt, Johannes L. Schönberger, Juan Nunez-Iglesias, François Boulogne, Joshua D. Warner, Neil Yager, Emmanuelle Gouillart, Tony Yu and the scikit-image contributors. PeerJ 2:e453 (2014) 

> <a name="ref5">[5]</a> **shiny: Easy web applications in R**<br />Rstudio Inc. (2014)