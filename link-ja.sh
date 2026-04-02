#!/bin/bash

set -Ceuo pipefail

cd $(dirname $0)

for jafile in ja/*.csv
do
  echo $jafile
  jabase=$(basename $jafile)
  case $jabase in
  BUFRCREX_*_notesja.csv)
    for gdir in BUFR4*/notes
    do
      echo $gdir
      ln -s -f ../../${jafile} $gdir/
    done
  ;;
  BUFRCREX_[TC]*|BUFR_TableD*|CREX_TableD*)
    for gdir in BUFR4*
    do
      echo $gdir
      ln -s -f ../${jafile} $gdir/
    done
  ;;
  GRIB2*)
    for gdir in GRIB2*
    do
      echo $gdir
      ln -s -f ../${jafile} $gdir/
    done
  ;;
  CodeFlag*)
    for gdir in GRIB2*
    do
      echo $gdir
      ln -s -f ../../${jafile} $gdir/notes/
    done
  ;;
  *)
    echo unsupported jabase=$jabase
    false
  ;;
  esac
done
