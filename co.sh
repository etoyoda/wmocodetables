#!/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin

dir=$(dirname $0)

ftname='FT2026-1'

for rep in GRIB2
do
  cd ${dir}
  if [ ! -d ${rep} ] ; then
    git clone https://github.com/wmo-im/${rep}
  fi
  cd ${rep}
  git fetch --all --prune
  git checkout main
  git worktree add ../${rep}-${ftname} origin/${ftname}
done
