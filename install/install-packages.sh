#!/bin/bash -x

pacman -Sy --noconfirm arch-install-scripts grep

pacstrap /mnt $(cat /install/packages.txt  | grep -v "^#" | grep -v "^ *\$")

#
# pacman -Syu --noconfirm
# pacman -S --noconfirm --needed git sudo base-devel go-pie
# ./add-user.sh
# echo "maulc ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/maulc
# chmod 0440 /etc/sudoers.d/maulc
# visudo -c
# git clone https://aur.archlinux.org/yay.git
# cd yay
# makepkg -si --noconfirm
# cd ..
# rm -rf yay
# su - maulc << EOF
#
# pacman --noconfirm --needed \$(cat $PWD/packages.txt  | grep -v "^#" | grep -v "^ *\$")
# EOF
