#!/bin/bash -e

sed -e 's|C! /etc/pam.d|C /etc/pam.d|' -i /usr/lib/tmpfiles.d/etc.conf

cd /usr/lib/firmware && mkdir -p intel-ucode &&
  cat /boot/intel-ucode.img | cpio -idmv &&
  mv kernel/x86/microcode/GenuineIntel.bin intel-ucode/ &&
  rm -r kernel
mkdir -p /extra-etc /etc/secureboot

mv /opt /usr/local/opt
