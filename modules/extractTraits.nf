process extract_traits {
    publishDir "${params.outdir}/diagnostics", mode: 'copy',
        saveAs: { filename ->
                if (filename.startsWith("mask_")) "mask/$filename"
                else if (filename.startsWith("overlay_")) "overlay/$filename"
                else if (filename.startsWith("crop_")) "crop/$filename"
                else if (filename.startsWith("hull_")) "convex_hull/$filename"
                else null
            }

    input:
        tuple val(index), path("original_images/*"), path("raw_masks/*"), path(ratios)
        val(labels)
        val(ignore_label)

    output:
        path '*.csv', emit: ch_results
        tuple val(index), val('mask'), path('mask_*'), optional: true, emit: ch_masks
        tuple val(index), val('overlay'), path('overlay_*'), optional: true, emit: ch_overlays
        tuple val(index), val('crop'), path('crop_*'), optional: true, emit: ch_crops
        tuple val(index), val('hull'), path('hull_*'), optional: true, emit: ch_hull

    script:
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
                        labels=dict(${labels}))
            draw_diagnostics(masks[index],
                            originals[index],
                            os.path.basename(name),
                            save_overlay=${params.save_overlay.toString().capitalize()},
                            save_mask=${params.save_mask.toString().capitalize()},
                            save_rosette=${params.save_rosette.toString().capitalize()},
                            save_hull=${params.save_hull.toString().capitalize()},
                            ignore_label=${ignore_label},
                            labels=dict(${labels}),
                            colormap=${cmap})
        """
}