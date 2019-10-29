#!/bin/bash
TARGET=desktop
OUTPUT=$1
USER_INIT=$2
sudo cp -av output/$TARGET/vmlinuz-linux $OUTPUT/vmlinuz-linux
cat output/$TARGET/initramfs-linux.img | gzip -d -c | cat - $USER_INIT | gzip -c | sudo tee $OUTPUT/initramfs-linux.img > /dev/null
