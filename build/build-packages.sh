#!/bin/bash
set -ex
pacman --needed -Sy --noconfirm arch-install-scripts base-devel git sudo awk
useradd -m build
echo 'build ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/build
chmod 0440 /etc/sudoers.d/build
visudo -c

for PROFILE in $SRCDIR/*-aur.txt
do
  PKG_DEST_DIR="$DESTDIR/packages/$(basename $PROFILE .txt)"
  for i in $(cat $PROFILE  | grep -v '^#' | grep -v '^ *$' | sort -u)
  do
    if ! [ -e ~build/build/$i/*.pkg.tar* ]
    then
      su - build << EOP
mkdir -p ~/build
  git clone https://aur.archlinux.org/$i.git ~/build/$i
  cd ~/build/$i
  (source PKGBUILD && gpg --recv-key \$validpgpkeys && sudo pacman -S --noconfirm --needed \${makedepends[@]} )
  export PKGEXT=.pkg.tar
  makepkg -sd --noconfirm --needed
EOP
    fi
    mkdir -p "$PKG_DEST_DIR"
    cp -av  ~build/build/$i/*.pkg.tar* $PKG_DEST_DIR
  done
done
