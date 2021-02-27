FROM mambaorg/micromamba:latest
LABEL authors="patrick.huether@gmi.oeaw.ac.at" \
    description="Container image containing DPP dependencies for ARADEEPOPSIS"

COPY environment.yml /environment.yml
RUN micromamba install -y -n base -f /environment.yml && \
    rm /opt/conda/pkgs/cache/*

EXPOSE 44333