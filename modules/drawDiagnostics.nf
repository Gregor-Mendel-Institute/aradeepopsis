process draw_diagnostics {
    publishDir "${params.outdir}/diagnostics", mode: 'copy',
        saveAs: { filename ->
                    if (filename.startsWith("mask_")) "summary/mask/$filename"
                    else if (filename.startsWith("overlay_")) "summary/overlay/$filename"
                    else if (filename.startsWith("crop_")) "summary/crop/$filename"
                    else null
                }
    input:
        tuple val(index), val(type), path(image)
    output:
        path('*.jpeg')

    script:
        def polaroid = params.polaroid ? '+polaroid' : ''
        """
        #!/usr/bin/env bash

        montage * -background 'black' -font Ubuntu-Condensed -geometry 200x200 -set label '%t' -fill white ${polaroid} "${type}_chunk_${index}.jpeg"
        """
}