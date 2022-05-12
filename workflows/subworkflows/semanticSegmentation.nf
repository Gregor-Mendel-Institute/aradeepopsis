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

def idx = 1
def max_dimension = ( params.model in ['A','B','C'] ? 602 : 256 )

include { RECORDS } from '../modules/buildRecords' addParams(size: max_dimension)
include { MODEL   } from '../modules/runPredictions'
include { DPP     } from '../modules/runDPP'

workflow SEGMENT {
    take:
        images
    main:
        Channel
            .fromPath(params.model_path, glob: false, checkIfExists: true)
            .collect()
            .set { model }

        RECORDS(
            images.collate(params.chunksize).map { tuple(idx++, it) }
        )

        RECORDS.out.invalid_images
            .collectFile(name: 'invalid_images.txt', storeDir: params.outdir)

        def masks = ( params.model in ['A','B','C'] ? MODEL(model,RECORDS.out.shards) : DPP(model,RECORDS.out.shards) )

    emit:
        RECORDS.out.originals.join(masks)
}