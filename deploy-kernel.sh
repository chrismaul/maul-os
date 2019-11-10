#!/bin/bash
UEFI=no
ADD_OPTS=""
while getopts ":v:c:k:s:a:u" opt; do
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
    s)
      SEC_KEYS=$OPTARG
      ;;
    a)
      ADD_OPTS=$OPTARG
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done

veritysetup format /dev/root/${VERS} /dev/root/${VERS}-verity | sudo tee /tmp/verity.txt

export ROOTHASH=$(cat /tmp/verity.txt | grep "Root hash:" | cut -f 2)

BOOT_DEV=${BOOT_DEV:-/dev/nvme0n1p1}
sudo mkdir -p /boot
sudo mount $BOOT_DEV /boot


MNT_DIR=$(mktemp -d)
sudo mount -o ro /dev/root/$VERS $MNT_DIR
if [ "$UEFI" != "yes" ]
then
  sudo mkdir -p /boot/$VERS
  sudo cp -v $MNT_DIR/boot/vmlinuz-linux /boot/$VERS
fi

if [ -z "$KERN_OPTS" ]
then
  KERN_OPTS="$(sed -e "s|maul-os-[^- ]*|$VERS|g" -e "s|roothash=[^ ]*|roothash=$ROOTHASH|" /proc/cmdline)"
else
  KERN_OPTS="$KERN_OPTS roothash=$ROOTHASH"
fi

if [ -n "$USER_INIT" ]
then
  sudo mount --bind $USER_INIT $MNT_DIR/extra-etc
fi
TMPFS_DIR=$(mktemp -d)
sudo mount -t tmpfs tmpfs $TMPFS_DIR
sudo mkdir -p $TMPFS_DIR/{upper,work}
sudo mount -t overlay overlay -o lowerdir=$MNT_DIR,upperdir=$TMPFS_DIR/upper/,workdir=$TMPFS_DIR/work/ $MNT_DIR
if [ -n "$SEC_KEYS" ]
then
  sudo mount --bind $SEC_KEYS $MNT_DIR/etc/secureboot
fi
if [ "$UEFI" = "yes" ]
then
  SRC=boot/$VERS.efi
  sudo chroot $MNT_DIR build-initramfs --uefi --kernel-cmdline "$KERN_OPTS" $ADD_OPTS /boot/$VERS.efi
else
  SRC=boot/initramfs-dracut.img
  sudo chroot $MNT_DIR build-initramfs $ADD_OPTS /$SRC
fi
DEST=/boot/$VERS
if [ "$UEFI" = "yes" ]
then
  DEST="/boot/efi/Linux/$VERS.efi"
fi
sudo cp -v $MNT_DIR/$SRC $DEST

if [ "$UEFI" != "yes" ]
then
  echo $KERN_OPTS
fi

sudo umount -R $MNT_DIR
rmdir $MNT_DIR
sudo umount -R $TMPFS_DIR
rmdir $TMPFS_DIR
