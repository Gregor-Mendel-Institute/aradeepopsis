FROM mambaorg/micromamba:0.13.0
LABEL authors="patrick.huether@gmi.oeaw.ac.at" \
    description="Container image containing DPP dependencies for ARADEEPOPSIS"

COPY environment.yml /
RUN apt-get update \
    && apt-get install --no-install-recommends -y procps \
    && micromamba install -y -n base -f /environment.yml \
    && micromamba clean -a && rm -rf /var/lib/{apt,dpkg,cache,log}

EXPOSE 44333
