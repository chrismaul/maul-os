#!/bin/bash
docker pull archlinux/base
docker run --rm --name build-arch \
  -v $PWD:/code \
  -it --privileged archlinux/base /code/install/build.sh
