#!/bin/bash -ex
if [ -z "$1" ]
then
  TARGETS="desktop k3s"
else
  TARGETS="$@"
fi

OUTPUTDIR=output

for TARGET in $TARGETS
do
  docker build --target $TARGET -t $TARGET .
  docker run --name $TARGET -w / $TARGET mksquashfs usr boot /output.squashfs

  test -e $OUTPUTDIR/$TARGET.squashfs && rm $OUTPUTDIR/$TARGET.squashfs
  docker cp $TARGET:/output.squashfs $OUTPUTDIR/$TARGET.squashfs
  docker cp $TARGET:/boot $OUTPUTDIR/$TARGET

  docker rm $TARGET
done
