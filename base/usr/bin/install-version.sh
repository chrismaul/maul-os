#!/bin/bash -e
SRC=$1
VERS=$2
VG_NAME=${VG_NAME:-root}
cleanup() {
  rm $DEST
}
if echo $SRC | egrep -q "^https?://"
then
  DEST=$(mktemp)
  trap cleanup EXIT
  curl -L $SRC -o $DEST
  if [ -z "$VERS" ]
  then
    VERS=$(basename $(dirname $SRC ) )
  fi
  SRC=$DEST
fi

if [ -z "$VERS" ]
then
  echo "Need vers as second args"
  exit 1
fi
FILESIZE=$(stat --printf="%s" $SRC)

echo "Install to version $VERS"

lvcreate -n maul-os-$VERS -L ${FILESIZE}B $VG_NAME

lvcreate -n maul-os-$VERS-verity -L 50M $VG_NAME

dd if=$SRC of=/dev/$VG_NAME/maul-os-$VERS bs=4M

deploy-kernel.sh -v maul-os-$VERS
