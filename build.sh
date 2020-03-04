#!/bin/bash -ex
DOCKER_OPTS=""
if [ "$1" = "no-cache" ]
then
  DOCKER_OPTS="--pull --no-cache"
  shift
fi
TARGET="${TARGET:-k8s}"

OUTPUTDIR=output

docker build --build-arg VERS=${VERS:-pr} -t $TARGET $DOCKER_OPTS .
docker run --name $TARGET -w / $TARGET /bin/bash -c 'mksquashfs $(ls / | egrep -v "(proc|sys|tmp)") /output.squashfs'

test -e $OUTPUTDIR/$TARGET.squashfs && rm $OUTPUTDIR/$TARGET.squashfs
docker cp $TARGET:/output.squashfs $OUTPUTDIR/$TARGET.squashfs
test -d $OUTPUTDIR/$TARGET && rm -r $OUTPUTDIR/$TARGET
docker cp $TARGET:/boot $OUTPUTDIR/$TARGET

docker rm $TARGET
