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

include { SUMMARY } from '../modules/drawDiagnostics'
include { SHINY   } from '../modules/launchShiny'

workflow QC {
    take:
        results
        diagnostics
    main:

        Channel
            .fromPath("${projectDir}/assets/shiny/app.R", checkIfExists: true)
            .collectFile(name: 'app.R', storeDir: "$params.outdir")
            .set { shinyapp }

        SUMMARY(
            diagnostics.groupTuple(by: 1)
        )

        SHINY(
            results,
            shinyapp
        )
}