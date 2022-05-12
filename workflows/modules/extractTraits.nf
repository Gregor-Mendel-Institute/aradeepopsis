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

process MEASURE {
    container "quay.io/beckerlab/aradeepopsis-base:${workflow.manifest.version}"
    
    publishDir "${params.outdir}/diagnostics", mode: 'copy',
        saveAs: { filename ->
                if (filename.startsWith("mask_")) "mask/$filename"
                else if (filename.startsWith("overlay_")) "overlay/$filename"
                else if (filename.startsWith("crop_")) "crop/$filename"
                else if (filename.startsWith("hull_")) "convex_hull/$filename"
                else null
            }

    input:
        tuple val(index), path("original_images/*"), path(ratios), path("raw_masks/*")
    output:
        path('*.csv'), emit: results
        tuple val(index), path("{crop,mask,overlay,hull}_*"), optional: true, emit: diagnostics
    script:
        def ignore_label = (params.model in ['B','C'] && params.ignore_senescence) ? "2" : (params.ignore_label ?: "None")
        def scale_ratios = ratios.name != 'ratios.p' ? "None" : "pickle.load(open('ratios.p','rb'))"
        def cmap = params.warhol ? "[[250,140,130],[119,204,98],[240,216,72],[82,128,199],[242,58,58]]" : "None"
        """
        #!/usr/bin/env python

        import os
        import pickle

        from traits import measure_traits, draw_diagnostics, load_images

        ratios = ${scale_ratios}
        masks, originals = load_images()

        for index, name in enumerate(originals.files):
            measure_traits(masks[index],
                        originals[index],
                        ratios[os.path.basename(name)] if ratios is not None else 1.0,
                        os.path.basename(name),
                        ignore_label=${ignore_label},
                        labels=dict(${params.labels}))
            draw_diagnostics(masks[index],
                            originals[index],
                            os.path.basename(name),
                            save_overlay=${params.save_overlay.toString().capitalize()},
                            save_mask=${params.save_mask.toString().capitalize()},
                            save_rosette=${params.save_rosette.toString().capitalize()},
                            save_hull=${params.save_hull.toString().capitalize()},
                            ignore_label=${ignore_label},
                            labels=dict(${params.labels}),
                            colormap=${cmap})
        """
}