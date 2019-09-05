#!/bin/bash
docker run --name build-arch \
  -v /etc/pacman.d/mirrorlist:/etc/pacman.d/mirrorlist:ro \
  -v /var/cache/pacman:/var/cache/pacman -v $PWD/install:/install:ro \
  -it --privileged archlinux/base /install/build.sh
