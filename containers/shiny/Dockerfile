FROM mambaorg/micromamba:0.13.0
LABEL authors="patrick.huether@gmi.oeaw.ac.at" \
    description="Container image containing DPP dependencies for ARADEEPOPSIS"

COPY environment.yml /environment.yml
RUN micromamba install -y -n base -f /environment.yml && micromamba clean -a

EXPOSE 44333