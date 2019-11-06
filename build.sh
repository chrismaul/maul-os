#!/bin/bash -ex
DOCKER_OPTS=""
if [ "$1" = "no-cache" ]
then
  DOCKER_OPTS="--pull --no-cache"
  shift
fi
if [ -z "$1" ]
then
  TARGETS="desktop k3s"
else
  TARGETS="$@"
fi

OUTPUTDIR=output

for TARGET in $TARGETS
do
  docker build --build-arg VERS=${VERS:-pr} --target $TARGET -t $TARGET $DOCKER_OPTS .
  docker run --name $TARGET -w / $TARGET /bin/bash -c 'mksquashfs $(ls / | egrep -v "(proc|sys|tmp)") /output.squashfs'

  test -e $OUTPUTDIR/$TARGET.squashfs && rm $OUTPUTDIR/$TARGET.squashfs
  docker cp $TARGET:/output.squashfs $OUTPUTDIR/$TARGET.squashfs
  docker cp $TARGET:/boot $OUTPUTDIR/$TARGET

  docker rm $TARGET
done
