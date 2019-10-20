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

for PROFILE in $SRCDIR/*.txt
do
  PKG_DEST_DIR="$DESTDIR/build/$(basename $PROFILE .txt)/packages"
  for i in $(cat $PROFILE  | grep -v '^#' | grep -v '^ *$' | sort -u)
  do
    if ! [ -e ~build/build/$i/*.pkg.tar.xz ]
    then
      su - build << EOP
mkdir -p ~/build
  git clone https://aur.archlinux.org/$i.git ~/build/$i
  cd ~/build/$i
  (source PKGBUILD && gpg --recv-key \$validpgpkeys) || true
  makepkg -s --noconfirm --needed
EOP
    fi
    mkdir -p "$PKG_DEST_DIR"
    cp -av  ~build/build/$i/*.pkg.tar.xz $PKG_DEST_DIR
  done
done
