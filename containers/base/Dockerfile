FROM continuumio/miniconda3
LABEL authors="patrick.huether@gmi.oeaw.ac.at" \
    description="Container image containing base dependencies for ARADEEPOPSIS"

COPY environment.yml /
RUN apt-get update && apt-get install -y procps graphviz && apt-get clean -y
RUN conda env create -f /environment.yml && conda clean -afy
ENV PATH /opt/conda/envs/aradeepopsis-base-v1.3/bin:$PATH
