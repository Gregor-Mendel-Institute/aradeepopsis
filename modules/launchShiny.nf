process launch_shiny {
    tag "http://${"uname".execute().text.trim() == "Darwin" ? "localhost" : "hostname -i".execute().text.trim()}:44333"
    containerOptions { workflow.profile.contains('singularity') ? '' : '-p 44333:44333' }
    executor 'local'
    cache false

    input:
        path ch_resultfile
        path app
        env LABELS
    script:
        """
        R -e "shiny::runApp('${app}', port=44333, host='0.0.0.0')"
        """
}