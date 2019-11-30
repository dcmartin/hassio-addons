ARG BUILD_FROM=hassioaddons/base-amd64:1.4.2
FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN apk --no-cache --update-cache add gcc gfortran python python-dev py-pip build-base wget freetype-dev libpng-dev

RUN echo "http://dl-8.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN apk --no-cache --update-cache add openblas-dev

RUN ln -s /usr/include/locale.h /usr/include/xlocale.h

# install python
RUN apk add --no-cache python3 py-pip freetype
RUN pip install --upgrade pip
RUN pip install --no-cache-dir pkg-config 
RUN pip install --no-cache-dir numpy==1.14.3 python-dateutil matplotlib
RUN pip install --no-cache-dir --deps pandas==0.23.0
RUN pip install --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org scipy

# install RASA NLU
RUN pip install rasa_nlu
RUN pip install rasa_nlu[spacy]
RUN python -m spacy download en_core_web_md
RUN python -m spacy link en_core_web_md en

# RASA setup
ARG RASADIR=/app
ARG PROJECTS=projects
ARG CONFIG=config_spacey.yml
ARG DATASRC="https://raw.githubusercontent.com/RasaHQ/rasa_nlu/master/data/examples/rasa/demo-rasa.json"
ARG DATA=rasa.json

RUN mkdir -p "${RASADIR}" && chmod 777 "${RASADIR}"
RUN mkdir -p "${RASADIR}/${PROJECTS}" && chmod 777 "${PROJECTS}"

COPY "${CONFIG}" "${RASADIR}/${CONFIG}"

RUN wget "${DATASRC}" -o "${RASADIR}/${DATA}"

COPY run.sh /
RUN chmod a+x /run.sh
CMD [ "/run.sh" ]
