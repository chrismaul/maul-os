#!/bin/bash -x
NAME=$1
ROOT_DEV=${ROOT_DEV:-/dev/nvme0n1p1}
sudo mkdir -p /boot
sudo mount $ROOT_DEV /boot
sudo dd if=$PWD/output/root.squashfs of=/dev/root/$NAME
cd output
sudo rm -r squashfs-root
sudo unsquashfs root.squashfs boot
sudo rsync -av squashfs-root/boot/ /boot/$NAME
