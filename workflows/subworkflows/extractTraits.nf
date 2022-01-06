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

nextflow.enable.dsl=2

include { MEASURE } from '../modules/extractTraits'

workflow TRAITS {
    take:
        masks
    main:
        MEASURE(
            masks
        )

    emit:
        MEASURE.out.results.collectFile(name: 'aradeepopsis_traits.csv', storeDir: params.outdir, keepHeader: true)
        MEASURE.out.diagnostics.transpose().map{ id, img -> tuple(id, img.name.split("_")[0], img) }
}