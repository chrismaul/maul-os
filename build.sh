#!/bin/bash
mkdir -p $PWD/mkosi.extra/packages
docker pull archlinux/base
docker run --rm  \
  -e DESTDIR=/output \
  -e SRCDIR=/build \
  -v $PWD/build:/build \
  -v $PWD/mkosi.extra/:/output \
  -v $PWD/build-packages.sh:/run.sh \
  -it archlinux/base /run.sh
