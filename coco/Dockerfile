FROM jupyter/scipy-notebook

MAINTAINER dcmartin <github@dcmartin.com>

RUN git clone https://github.com/cocodataset/cocoapi.git && cd cocoapi/PythonAPI && make && make install

COPY run.sh /usr/local/bin

CMD /usr/local/bin/run.sh
