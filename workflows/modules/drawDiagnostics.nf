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

process SUMMARY {
    container "quay.io/beckerlab/aradeepopsis-base:${workflow.manifest.version}"

    publishDir "${params.outdir}/diagnostics", mode: 'copy',
        saveAs: { filename ->
                    if (filename.startsWith("mask_")) "summary/mask/$filename"
                    else if (filename.startsWith("overlay_")) "summary/overlay/$filename"
                    else if (filename.startsWith("crop_")) "summary/crop/$filename"
                    else null
                }
    when:
        params.summary_diagnostics

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