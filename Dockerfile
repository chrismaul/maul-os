FROM archlinux/base AS packages
COPY build-packages.sh /run.sh
COPY build /build
RUN DESTDIR=/output SRCDIR=/build /run.sh

FROM archlinux/base AS base
ARG VERS=dev
ARG ARCH_MIRROR=http://mirror.math.princeton.edu/pub/archlinux
RUN sed -i "1s|^|Server = $ARCH_MIRROR/\$repo/os/\$arch\n|" /etc/pacman.d/mirrorlist
RUN pacman -Syu --noconfirm
RUN pacman -Sy --needed --noconfirm \
  base \
  base-devel \
  squashfs-tools \
  acpi \
  man-db \
  man-pages \
  binutils \
  expect \
  which \
  bind-tools \
  bc \
  cpio \
  docker \
  docker-compose \
  jq \
  rsync \
  vim \
  wget \
  curl \
  cryptsetup \
  device-mapper \
  dhcpcd \
  e2fsprogs \
  efibootmgr \
  intel-ucode \
  linux \
  linux-headers \
  linux-firmware \
  systemd \
  sudo \
  lvm2 \
  usbutils \
  inetutils \
  fwupd \
  efitools \
  sbsigntools \
  python-netifaces \
  tpm2-tools \
  tpm2-abrmd
COPY base /

RUN sed -e "s/^HOOKS=.*\$/HOOKS=(base systemd sd-vroot sd-localization sd-lvm2 modconf block keyboard sd-vconsole sd-encrypt)/" \
  -e "s/^MODULES=.*\$/MODULES=(squashfs virtio virtio_pci virtio_blk ext4)/" -i /etc/mkinitcpio.conf

RUN systemctl enable setup-customize-initrd.service && \
  systemctl enable setup-profile-home.service

RUN sed -e 's|C! /etc/pam.d|C /etc/pam.d|' -i /usr/lib/tmpfiles.d/etc.conf

RUN cd /usr/lib/firmware && mkdir -p intel-ucode && \
  cat /boot/intel-ucode.img | cpio -idmv && \
  mv kernel/x86/microcode/GenuineIntel.bin intel-ucode/ && \
  rm -r kernel

RUN mkdir -p /extra-etc /etc/secureboot && update-os-id-vers base $VERS

FROM base AS desktop
RUN update-os-id-vers desktop
RUN pacman -Sy --needed --noconfirm \
  atom \
  git-crypt \
  diffutils \
  libp11 \
  meld \
  ipmitool \
  firefox \
  aspell-en \
  hunspell-en_US \
  wireless_tools \
  iw \
  wpa_supplicant \
  kubectx \
  fzf \
  weston \
  gnome \
  gdm \
  networkmanager \
  evolution \
  evolution-ews \
  dmidecode \
  networkmanager-openconnect \
  pcsclite \
  opensc \
  ccid \
  yubikey-personalization \
  yubikey-manager \
  libu2f-host \
  pam-u2f \
  ruby-bundler \
  flatpak

COPY --from=packages /output/build/desktop/packages /packages
RUN rm /opt && mkdir -p /opt
RUN pacman -U /packages/* --noconfirm --needed
RUN rm -r /packages
COPY desktop /
RUN for i in \
  etc/environment \
  etc/xdg/ \
  etc/cloud/ \
  etc/security/ \
  etc/gdm/ \
  etc/geoclue/ \
  etc/UPower/ \
  etc/ca-certificates/ \
  etc/ssl/ \
  etc/pam.d/ \
  etc/profile.d/ \
  etc/bash.bashrc \
  etc/fonts/ \
  etc/pulse/ \
  etc/fwupd/ \
  etc/pki/ \
  etc/NetworkManager/; \
do \
  [ -e "/$i" ] && rsync -av /$i /usr/share/factory/$i ; \
done

RUN echo "HOOKS+=('sd-plymouth' 'autodetect')" >> /etc/mkinitcpio.conf && \
  echo "MODULES+=('i915')" >> /etc/mkinitcpio.conf

RUN echo \
  pcscd.service \
  bluetooth.service \
  coldplug.service \
  gdm.service \
  | xargs -n 1 systemctl enable

RUN mkdir -p /usr/lib/systemd/user/default.target.wants && \
  ln -s ../docker.service /usr/lib/systemd/user/default.target.wants/

RUN rm /usr/lib/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist && cp /etc/libccid_Info.plist /usr/lib/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist && \
  rm /usr/lib/systemd/system/sshdgenkeys.service && \
  rm /usr/lib/systemd/system/docker* && \
  mv /etc/dbus-1/system.d/wpa_supplicant.conf /usr/share/dbus-1/system.d/

RUN rsync --ignore-existing -av /etc/systemd/ /usr/lib/systemd/


RUN plymouth-set-default-theme -R dark-arch

RUN build-initramfs /boot/initramfs-dracut.img

RUN [ ! -d "/usr/local/opt" ] && ( mv /opt /usr/local/opt && ln -sf usr/local/opt /opt )

FROM base AS k3s
RUN update-os-id-vers k3s
RUN pacman -Sy --needed --noconfirm \
  dhcpcd \
  openssh \
  nfs-utils \
  grub

COPY --from=packages /output/build/k3s/packages /packages
RUN rm /opt && mkdir -p /opt
RUN pacman -U /packages/* --noconfirm --needed
RUN rm -r /packages
COPY k3s /
RUN for i in \
  etc/environment \
  etc/xdg/ \
  etc/cloud/ \
  etc/security/ \
  etc/ca-certificates/ \
  etc/ssl/ \
  etc/pam.d/ \
  etc/profile.d/ \
  etc/bash.bashrc \
  ; \
do \
  [ -e "/$i" ] && rsync -av /$i /usr/share/factory/$i ; \
done

RUN echo "MODULES+=('dm-raid' 'raid0' 'raid1' 'raid10' 'raid456')" >> /etc/mkinitcpio.conf

RUN echo \
  k3s.service \
  docker.service \
  mnt-data.mount \
  systemd-networkd.service \
  systemd-resolved.service \
  sshd.service \
  cloud-init-local.service \
  cloud-final.service \
  | xargs -n 1 systemctl enable


RUN rsync --ignore-existing -av /etc/systemd/ /usr/lib/systemd/

RUN build-initramfs /boot/initramfs-dracut.img
RUN [ ! -d "/usr/local/opt" ] && ( mv /opt /usr/local/opt && ln -sf usr/local/opt /opt )
