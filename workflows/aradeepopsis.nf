/*
Copyright (C) 2019-2022 Patrick Hüther

This file is part of ARADEEPOPSIS.
ARADEEPOPSIS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ARADEEPOPSIS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ARADEEPOPSIS.  If not, see <https://www.gnu.org/licenses/>.
*/

if (!params.masks) {
    switch(params.model) {
        case 'A':
            model_path = "https://cdn.vbc.ac.at/clip/reframe/data/aradeepopsis/1_class_${params.multiscale ? 'multi' : 'single'}scale.pb"
            label_spec = "class_background=0,class_norm=1"
            break
        case 'B':
            model_path = "https://cdn.vbc.ac.at/clip/reframe/data/aradeepopsis/2_class_${params.multiscale ? 'multi' : 'single'}scale.pb" 
            label_spec = "class_background=0,class_norm=1,class_senesc=2"
            break
        case 'C':
            model_path = "https://cdn.vbc.ac.at/clip/reframe/data/aradeepopsis/3_class_${params.multiscale ? 'multi' : 'single'}scale.pb"
            label_spec = "class_background=0,class_norm=1,class_senesc=2,class_antho=3"
            break
        case 'DPP':
            model_path = [
                         params.dpp_checkpoint  + 'checkpoint',
                         params.dpp_checkpoint  + 'tfhSaved.data-00000-of-00001',
                         params.dpp_checkpoint  + 'tfhSaved.index',
                         params.dpp_checkpoint  + 'tfhSaved.meta',
                         ]
            label_spec = params.label_spec ?: "class_background=0,class_norm=1"
            break
    }
    include { SEGMENT } from  './subworkflows/semanticSegmentation' addParams(model_path: model_path)
} else {
    assert params.label_spec, "ERROR! The --masks parameter requires a comma-separated list of class names and corresponding pixel values. Example: 'class_background=0,class_norm=255' (quotation marks required!)"
    label_spec = params.label_spec
    include { MASKS  } from './subworkflows/presegmentedMasks'
}

include { TRAITS } from './subworkflows/extractTraits'  addParams(labels: label_spec)
include { QC     } from './subworkflows/qualityControl' addParams(labels: label_spec)

workflow ARADEEPOPSIS {
    main:
        Channel.fromPath(params.images, checkIfExists: true) \
            | ( params.masks ? MASKS : SEGMENT ) \
            | TRAITS \
            | QC
}
