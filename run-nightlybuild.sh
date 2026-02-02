#!/bin/bash

PATH=/usr/local/bin:/usr/bin:/bin
cd $(dirname $0)

dest=toyoda-eizi.net:c/wmocodetables/

exec 2>&1 > z.makepdf.log
set -vx
git pull
rm -f tdcf-tables.adoc.bak
make pdf
rc=$?
echo make pdf status $rc
if ! egrep -q 'make: Nothing to be done for .pdf' z.makepdf.log
then
  scp tdcf-tables.pdf ${dest}
  scp z.makepdf.log ${dest}
fi
