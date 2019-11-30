#!/bin/bash

if [ -z ${DATADIR} ]; then DATADIR=/coco; fi

if [ ! -d ${DATADIR} ]; then
  echo "No ${DATADIR} directory" > /dev/stderr
  exit 1
fi

if [ ! -d ${DATADIR} ]; then
  mkdir -p ${DATADIR}
fi

SITE="/images.cocodataset.org"
echo "Getting data from ${SITE}" > /dev/stderr

  SET="/zips/train2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/zips/val2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/zips/test2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/zips/unlabeled2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/annotations/annotations_trainval2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/annotations/stuff_annotations_trainval2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/annotations/panoptic_annotations_trainval2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/annotations/image_info_test2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

  SET="/annotations/image_info_unlabeled2017.zip"
  SETDIR=${DATADIR}/${SET%.*}
  if [ ! -d "${SETDIR}" ]; then mkdir -p "${SETDIR}"; fi   
  cd ${SETDIR}
  if [ ! -s "${SET##*/}" ]; then
    echo "Retrieving ${SET}" > /dev/stderr
    wget "http:/${SITE}${SET}" && unzip "${SET##*/}"
  else
    echo "Retrieved ${SET}" > /dev/stderr
  fi

cd && ln -s ${DATADIR}/* work/

jupyter notebook --generate-config

# start as normal
/usr/local/bin/start-notebook.sh
