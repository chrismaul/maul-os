#!/bin/bash
UEFI=no
while getopts ":v:c:k:u" opt; do
  case ${opt} in
    v)
      VERS=$OPTARG
      ;;
    c)
      USER_INIT=$OPTARG
      ;;
    u)
      UEFI=yes
      ;;
    k)
      KERN_OPTS=$OPTARG
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done

BOOT_DEV=${BOOT_DEV:-/dev/nvme0n1p1}
sudo mkdir -p /boot
sudo mount $BOOT_DEV /boot
sudo mkdir -p /boot/$VERS

MNT_DIR=$(mktemp -d)
sudo mount -o ro /dev/root/$VERS $MNT_DIR
sudo cp -v $MNT_DIR/boot/vmlinuz-linux /boot/$VERS
if [ -n "$USER_INIT" ]
then
  sudo mount --bind $USER_INIT $MNT_DIR/extra-etc
  sudo mount -t tmpfs tmpfs $MNT_DIR/var/tmp
  sudo mkdir -p $MNT_DIR/var/tmp/overlay/{upper,work}
  sudo mount -t overlay overlay -o lowerdir=$MNT_DIR/boot,upperdir=$MNT_DIR/var/tmp/overlay/upper/,workdir=$MNT_DIR/var/tmp/overlay/work/ $MNT_DIR/boot
  if [ "$UEFI" = "yes" ]
  then
    sudo chroot $MNT_DIR build-initramfs --uefi --kernel-cmdline "$KERN_OPTS" /boot/$VERS.efi
  else
    sudo chroot $MNT_DIR build-initramfs
  fi
fi
DEST=/boot/$VERS
if [ "$UEFI" = "yes" ]
then
  DEST="$DEST/boot.efi"
fi
#sudo cp -v $MNT_DIR/boot/initramfs-dracut.img $DEST

#sudo umount -R $MNT_DIR
#rmdir $MNT_DIR
