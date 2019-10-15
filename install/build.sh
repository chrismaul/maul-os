#!/bin/bash
set -ex
export CODE_DIR=/code
export OUTPUT=$CODE_DIR/output
export CONFIG_ROOT=$CODE_DIR/install
rm -r $OUTPUT
cp $CONFIG_ROOT/mirrorlist /etc/pacman.d/mirrorlist
mkdir -p $OUTPUT
pacman --needed -Sy --noconfirm arch-install-scripts base-devel git sudo rsync squashfs-tools

pacstrap -c $OUTPUT $(cat $CONFIG_ROOT/packages.txt  | grep -v '^#' | grep -v '^ *$' | sort -u)

useradd -m build
echo 'build ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/build
chmod 0440 /etc/sudoers.d/build
visudo -c
su - build << EOP
mkdir -p ~/build
  git clone https://aur.archlinux.org/plymouth.git ~/build/plymouth
  cd ~/build/plymouth
  (source PKGBUILD && gpg --recv-key $validpgpkeys) || true
  makepkg -si --noconfirm --needed
EOP
pacman -U ~build/build/plymouth/*.pkg.tar.xz --noconfirm --needed --root $OUTPUT

for i in $(cat $CONFIG_ROOT/aur-packages.txt  | grep -v '^#' | grep -v '^ *$' | sort -u)
do
su - build << EOP
mkdir -p ~/build
  git clone https://aur.archlinux.org/$i.git ~/build/$i
  cd ~/build/$i
  (source PKGBUILD && gpg --recv-key \$validpgpkeys) || true
  makepkg -s --noconfirm --needed
EOP
# pacman -U ~build/build/$i/*.pkg.tar.xz --noconfirm --needed --root $OUTPUT
done
pacman -U ~build/build/*/*.pkg.tar.xz --noconfirm --needed --root $OUTPUT

rsync -rlptDv $CODE_DIR/files/ $OUTPUT/

for i in \
  etc/environment \
  etc/xdg/ \
  etc/cloud/ \
  etc/security/ \
  etc/dbus-1/ \
  etc/NetworkManager/ \
  etc/ca-certificates/ \
  etc/ssl/ \
  etc/pulse/ \
  etc/fonts/ \
  etc/profile.d/ \
  etc/bash.bashrc \
  etc/bash.bash_logout
do
  rsync -av $OUTPUT/$i $OUTPUT/usr/share/factory/$i
done


sed -i 's/^HOOKS=.*$/HOOKS=(base systemd sd-plymouth keyboard sd-vconsole sd-vroot modconf sd-lvm2 sd-encrypt block filesystems fsck)/' $OUTPUT/etc/mkinitcpio.conf
sed -i 's/^MODULES=.*$/MODULES=(squashfs virtio virtio_pci virtio_blk ext4 i915)/' $OUTPUT/etc/mkinitcpio.conf


for i in $(cat $CONFIG_ROOT/service-enable.txt  | grep -v "^#" | grep -v "^ *\$")
do
  ln -sf ../$i $OUTPUT/usr/lib/systemd/system/multi-user.target.wants/$i
#  systemctl enable $i
done

mkdir -p $OUTPUT/usr/lib/systemd/user/default.target.wants

for i in $(cat $CONFIG_ROOT/user-service-enable.txt  | grep -v "^#" | grep -v "^ *\$")
do
  ln -sf ../$i $OUTPUT/usr/lib/systemd/user/default.target.wants/$i
#  systemctl enable $i
done

arch-chroot $OUTPUT locale-gen


rm $OUTPUT/usr/lib/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist && cp $OUTPUT/etc/libccid_Info.plist $OUTPUT/usr/lib/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist

# disable ssh for cloud init

sed -i 's/^.*sshd.*$//' $OUTPUT/usr/lib/systemd/system/cloud-init.service
sed -i 's/^.*systemd-networkd.*$//' $OUTPUT/usr/lib/systemd/system/cloud-init.service
rm $OUTPUT/usr/lib/systemd/system/systemd-network*
rm $OUTPUT/usr/lib/systemd/system/docker*

if [ ! -d "$OUTPUT/usr/local/opt" ]
then
  mv $OUTPUT/opt $OUTPUT/usr/local/opt
  ln -sf usr/local/opt $OUTPUT/opt
fi

arch-chroot $OUTPUT plymouth-set-default-theme -R dark-arch

arch-chroot $OUTPUT mkinitcpio -p linux

(cd $OUTPUT; mksquashfs * ../output.squashfs)
