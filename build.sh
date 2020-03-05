#!/bin/bash -ex
DOCKER_OPTS=""
BUILD="no"
if [ "$1" = "no-cache" ]
then
  DOCKER_OPTS="--pull --no-cache"
  BUILD="yes"
  shift
fi

OUTPUTDIR=output

if [ ! -e $PWD/build/packages ]
then
  BUILD="yes"
fi

if [ "$BUILD" = "yes" ]
then
  for i in $PWD/build/*-aur.txt
  do
    mkdir -p $PWD/build/packages/$(basename $i .txt)
  done
  docker run --rm \
    -v $PWD/build:/build \
    -e DESTDIR=/build \
    -e SRCDIR=/build \
     archlinux/base /build/build-packages.sh
fi

for TARGET
do
  docker build -f Dockerfile.$TARGET --build-arg VERS=${VERS:-pr} -t $TARGET $DOCKER_OPTS .
  docker run --name $TARGET -w / $TARGET /bin/bash -c 'mksquashfs $(ls / | egrep -v "(proc|sys|tmp)") /output.squashfs'

  test -e $OUTPUTDIR/$TARGET.squashfs && rm $OUTPUTDIR/$TARGET.squashfs
  docker cp $TARGET:/output.squashfs $OUTPUTDIR/$TARGET.squashfs
  test -d $OUTPUTDIR/$TARGET && rm -r $OUTPUTDIR/$TARGET
  docker cp $TARGET:/boot $OUTPUTDIR/$TARGET

  docker rm $TARGET
done
