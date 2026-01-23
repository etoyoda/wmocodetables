#!/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

dir=$(dirname $0)
if [ X"${dir}" = X"." ]; then
  dir=$(pwd)
fi

ftname='FT2026-1'

for rep in GRIB2 BUFR4 CCT
do
  cd ${dir}
  if [ ! -d ${rep} ] ; then
    git clone https://github.com/wmo-im/${rep}
    cd ${rep}
    git fetch --all --prune
    git checkout main
  fi
  cd ${dir}
  cd ${rep}
  if [ ! -d ../${rep}-${ftname} ]; then
    git worktree add ../${rep}-${ftname} origin/${ftname}
  fi
done
