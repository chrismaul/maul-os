#!/bin/bash -e
UEFI=no
ADD_OPTS=""
USER_INIT=/mnt/cidata/extra-etc.tar.gz
SEC_KEYS=/mnt/cidata/secureboot
if [ -e /dev/disk/by-label/cidata ] && ! findmnt /mnt/cidata > /dev/null
then
  sudo mkdir -p /mnt/cidata
  sudo mount -o ro /dev/disk/by-label/cidata /mnt/cidata
fi
if [ -e "/mnt/cidata/deploy-kernel.vars" ]
then
  source /mnt/cidata/deploy-kernel.vars
fi
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

if [ -z "$BOOT_DEV" ]
then
  if [ -e "/dev/nvme0n1p1" ]
  then
    BOOT_DEV=/dev/nvme0n1p1
  else
    BOOT_DEV=/dev/sda1
  fi
fi

echo "Using vars:
VERS: $VERS
USER_INIT: $USER_INIT
UEFI: $UEFI
KERN_OPTS: $KERN_OPTS
SEC_KEYS: $SEC_KEYS
ADD_OPTS: $ADD_OPTS
BOOT_DEV: $BOOT_DEV
"

sudo veritysetup format /dev/root/${VERS} /dev/root/${VERS}-verity | sudo tee /tmp/verity.txt

export ROOTHASH=$(cat /tmp/verity.txt | grep "Root hash:" | cut -f 2)

MNT_DIR=$(mktemp -d)
TMP_MNT_DIR=$(mktemp -d)
sudo mount -o ro /dev/root/$VERS $TMP_MNT_DIR

if [ -z "$KERN_OPTS" ]
then
  KERN_OPTS="$(sed \
    -e "s|systemd.verity_root_data=[^ ]* |systemd.verity_root_data=/dev/root/$VERS |g" \
    -e "s|systemd.verity_root_hash=[^ ]* |systemd.verity_root_hash=/dev/root/${VERS}-verity |g" \
    -e "s|roothash=[^ ]*|roothash=$ROOTHASH|" \
    -e "s|^ *||" \
    -e 's| *$||' \
    /proc/cmdline)"
else
  KERN_OPTS=$(echo $KERN_OPTS | sed -e "s|%VERS%|$VERS|g" -e "s|%ROOTHASH%|$ROOTHASH|g")
fi

TMPFS_DIR=$(mktemp -d)
sudo mount -t tmpfs tmpfs $TMPFS_DIR
sudo mkdir -p $TMPFS_DIR/{upper,work}
sudo mount -t overlay overlay -o lowerdir=$TMP_MNT_DIR,upperdir=$TMPFS_DIR/upper/,workdir=$TMPFS_DIR/work/ $MNT_DIR

if [ -n "$USER_INIT" ] && [ -e "$USER_INIT" ]
then
  sudo tar xf $USER_INIT -C $MNT_DIR/extra-etc
fi

if [ -n "$SEC_KEYS" ] && [ -d "$SEC_KEYS" ]
then
  sudo mount --bind $SEC_KEYS $MNT_DIR/etc/secureboot
fi

if [ "$UEFI" = "yes" ]
then
  SRC=boot/$VERS.efi
  sudo chroot $MNT_DIR build-initramfs $ADD_OPTS --uefi --kernel-cmdline "$KERN_OPTS" /boot/$VERS.efi
else
  SRC=boot/initramfs-dracut.img
  sudo chroot $MNT_DIR build-initramfs $ADD_OPTS /boot/$VERS.img
fi

for DEV in $BOOT_DEV
do
  if ! findmnt /boot > /dev/null
  then
    sudo mkdir -p /boot
    sudo mount $DEV /boot
  fi

  DEST=/boot/$VERS
  if [ "$UEFI" = "yes" ]
  then
    sudo cp -v $MNT_DIR/$SRC /boot/efi/Linux/$VERS.efi
  else
    sudo mkdir -p /boot/$VERS
    KERNEL=vmlinuz-linux
    if echo $ADD_OPTS | grep -q "lts"
    then
      KERNEL="$KERNEL-lts"
    fi
    sudo cp -v $MNT_DIR/boot/$KERNEL /boot/$VERS/vmlinuz-linux
    sudo cp -v $MNT_DIR/boot/$VERS.img /boot/$VERS/initramfs-linux.img
    echo "$KERN_OPTS" | sudo tee /boot/$VERS/args.txt

    GRUB_CONFIG="/boot/grub/grub.cfg"
    echo "set default=0
  set timeout=5" | sudo tee $GRUB_CONFIG
    for i in $(ls /boot | sort -Vr )
    do
      if [ -f /boot/$i/args.txt ]
      then
        KERNEL_LOC=$i/vmlinuz-linux
        echo "menuentry \"$i\" {
          linux /$i/vmlinuz-linux $(cat /boot/$i/args.txt)
          initrd /$i/initramfs-linux.img
        } " | sudo tee -a $GRUB_CONFIG
      fi
    done
  fi
  sudo umount /boot
done
sudo umount -R $MNT_DIR
rmdir $MNT_DIR
sudo umount -R $TMP_MNT_DIR
rmdir $TMP_MNT_DIR
sudo umount -R $TMPFS_DIR
rmdir $TMPFS_DIR
