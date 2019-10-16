#!/bin/bash
set -ex
pacman --needed -Sy --noconfirm arch-install-scripts base-devel git sudo
useradd -m build
echo 'build ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/build
chmod 0440 /etc/sudoers.d/build
visudo -c
# Need to install package before hand because it is a dependecny for other packages
su - build << EOP
mkdir -p ~/build
  git clone https://aur.archlinux.org/plymouth.git ~/build/plymouth
  cd ~/build/plymouth
  (source PKGBUILD && gpg --recv-key \$validpgpkeys) || true
  makepkg -si --noconfirm --needed
EOP

for i in $(cat $SRCDIR/aur-packages.txt  | grep -v '^#' | grep -v '^ *$' | sort -u)
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

mkdir -p $DESTDIR/packages/
cp -av ~build/build/*/*.pkg.tar.xz $DESTDIR/packages/
