#!/bin/bash
set -ex
pacman --needed -Sy --noconfirm arch-install-scripts base-devel git sudo

pacstrap -c /mnt $(cat /install/packages.txt  | grep -v '^#' | grep -v '^ *$' | sort -u)

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
#pacman -U ~build/build/plymouth/*.pkg.tar.xz --noconfirm --needed --root /mnt

for i in $(cat /install/aur-packages.txt  | grep -v '^#' | grep -v '^ *$' | sort -u)
do
su - build << EOP
mkdir -p ~/build
  git clone https://aur.archlinux.org/$i.git ~/build/$i
  cd ~/build/$i
  (source PKGBUILD && gpg --recv-key \$validpgpkeys) || true
  makepkg -s --noconfirm --needed
EOP
# pacman -U ~build/build/$i/*.pkg.tar.xz --noconfirm --needed --root /mnt
done
pacman -U ~build/build/*/*-x86_64.pkg.tar.xz --noconfirm --needed --root /mnt
