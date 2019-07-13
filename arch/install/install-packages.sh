#!/bin/bash -x
pacman -Syu --noconfirm
pacman -S --noconfirm --needed git sudo base-devel go-pie
./add-user.sh
echo "maulc ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/maulc
chmod 0440 /etc/sudoers.d/maulc
visudo -c
su - maulc << EOF
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay
yay -S --noconfirm --needed \$(cat $PWD/packages.txt  | grep -v "^#" | grep -v "^ *\$")
EOF
