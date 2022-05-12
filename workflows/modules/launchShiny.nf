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

process SHINY {
    container "quay.io/beckerlab/aradeepopsis-shiny:${workflow.manifest.version}"
    containerOptions { workflow.profile.contains('singularity') || workflow.profile.contains('charliecloud') ? '' : '-p 44333:44333' }
    executor 'local'
    cache false
    beforeScript "export LABELS=${params.labels}"

    input:
        path(results)
        path(app)
    when:
        params.shiny
    script:
        def ip = "uname".execute().text.trim() == "Darwin" ? "localhost" : "hostname -i".execute().text.trim()
        log.error"""
        Visit the shiny server running at ${'http://' << ip << ':44333'} to inspect the results.
        Closing the browser window will terminate the pipeline.
        """.stripIndent()
        """
        R -e "shiny::runApp('${app}', port=44333, host='0.0.0.0')"
        """
}