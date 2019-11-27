FROM continuumio/miniconda3
MAINTAINER Patrick Hüther <patrick.huether@gmi.oeaw.ac.at>
LABEL authors="patrick.huether@gmi.oeaw.ac.at" \
    description="Container image containing all dependencies for aradeepopsis"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/aradeepopsis/bin:$PATH