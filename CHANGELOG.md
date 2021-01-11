# Changelog

## [v1.3](https://github.com/Gregor-Mendel-Institute/aradeepopsis/releases/tag/v1.3) - 2021-01-11

* changed container registry from docker.io to quay.io
* improved image visualization and plot rendering in Shiny app (see [#54](https://github.com/Gregor-Mendel-Institute/aradeepopsis/issues/54)) thanks @dschneiderch for input
* updated `scikit-image` `0.17.2` > `0.18.1`
* updated `imagemagick` dependency `7.0.10_23` > `7.0.10_28`
* updated `shinycssloaders` dependency `0.3` > `1.0.0`
* updated `slickr` dependency `0.4.9` > `0.5.0`
* added publication doi to pipeline manifest
* changed (back) download links in pipeline to fetch pretrained models from Dropbox instead of Zenodo ([#53](https://github.com/Gregor-Mendel-Institute/aradeepopsis/issues/53#issue-779431868))
* added charliecloud profile (needs nextflow >= 20.12.0-edge)
* fixed plotting of leaf states over time in Shiny app (when appropriate metadata are provided)
* added config for LRZ coolmuc2

## [v1.2.1](https://github.com/Gregor-Mendel-Institute/aradeepopsis/releases/tag/v1.2.1) - 2020-07-23

* updated pipeline to fetch trained models from the deposited [Zenodo record](https://doi.org/10.5281/zenodo.3946321) instead of Dropbox
* fixed an issue where the DPP addon produced sub-par segmentation results compared to the [tools](https://deep-plant-phenomics.readthedocs.io/en/latest/Tools/#vegetation-segmentation-network) implementation in Deep Plant Phenomics.
* updated shiny app to show visualizations sorted by filename

## [v1.2](https://github.com/Gregor-Mendel-Institute/aradeepopsis/releases/tag/v1.2) - 2020-07-15

* updated `shiny` dependency `1.4.0` > `1.5.0`
* added a more informative log message if pipeline fails on systems with insufficient memory
* added `--ignore_label` parameter to exclude a segmentation class for trait calculation.
* added `--label_spec` parameter to allow for mapping of segmentation classes to pixel values of user-supplied segmentation masks. This is a requirement for the `--masks` parameter now.
* updated base.config to avoid out-of-memory issues when running with `--multiscale`
* added Dockerfile + Conda environment for DPP v2.1.0
* factored out Shiny dependencies into separate container (should be easier to deploy as a hosted Shiny app now)
* added `--model 'DPP'` and `--dpp_checkpoint` to allow for custom segmentation models, trained using the [Deep Plant Phenomics](https://github.com/p2irc/deepplantphenomics) framework
* added `--masks` parameter to skip semantic segmentation and run trait extraction using user-supplied masks
* fixed an issue where the pipeline would crash if the input image contains an alpha channel
* updated configuration for CBE cluster
* added log message to show current parameter settings when starting a pipeline run
* updated `scikit-image` `0.16.2` > `0.17.2`
* updated `imagemagick` dependency `7.0.9_27` > `7.0.10_23`

## [v1.1](https://github.com/Gregor-Mendel-Institute/aradeepopsis/releases/tag/v1.1) - 2020-05-13

* disabled task error strategy for pipeline runs on local computers
* fixed an issue where the network address of the shiny application was not correctly displayed on computers running MacOS

## [v1.0](https://github.com/Gregor-Mendel-Institute/aradeepopsis/releases/tag/v1.0) - 2020-04-02

Initial pipeline release
