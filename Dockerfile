FROM archlinux/base AS packages
COPY build-packages.sh /run.sh
COPY build /build
RUN DESTDIR=/output SRCDIR=/build /run.sh

FROM archlinux/base AS base
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
  ca-certificates \
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
  tpm2-abrmd \
  screen \
  cpupower
COPY base /
COPY deploy-kernel.sh /usr/bin/
RUN sed -e "s/^HOOKS=.*\$/HOOKS=(base systemd sd-vroot sd-localization sd-lvm2 modconf block keyboard sd-vconsole sd-encrypt)/" \
  -e "s/^MODULES=.*\$/MODULES=(squashfs virtio virtio_pci virtio_blk ext4)/" -i /etc/mkinitcpio.conf

RUN systemctl enable setup-customize-initrd.service && \
  systemctl enable setup-profile-home.service && \
  systemctl enable coldplug.service

RUN sed -e 's|C! /etc/pam.d|C /etc/pam.d|' -i /usr/lib/tmpfiles.d/etc.conf

RUN cd /usr/lib/firmware && mkdir -p intel-ucode && \
  cat /boot/intel-ucode.img | cpio -idmv && \
  mv kernel/x86/microcode/GenuineIntel.bin intel-ucode/ && \
  rm -r kernel

RUN mkdir -p /extra-etc /etc/secureboot

FROM base AS desktop
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
  yubioath-desktop \
  libu2f-host \
  pam-u2f \
  ruby-bundler \
  flatpak \
  vlc \
  libmfx \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  pipewire \
  socat

COPY --from=packages /output/build/desktop/packages /packages
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
  etc/fancontrol \
  etc/pam.d/ \
  etc/profile.d/ \
  etc/bash.bashrc \
  etc/fonts/ \
  etc/pulse/ \
  etc/fwupd/ \
  etc/pki/ \
  etc/ethertypes \
  etc/NetworkManager/; \
do \
  [ -e "/$i" ] && rsync -av /$i /usr/share/factory/$i ; \
done

RUN echo "HOOKS+=('sd-plymouth' 'autodetect')" >> /etc/mkinitcpio.conf && \
  echo "MODULES+=('i915')" >> /etc/mkinitcpio.conf

RUN echo \
  pcscd.service \
  bluetooth.service \
  gdm.service \
  | xargs -n 1 systemctl enable

RUN mkdir -p /usr/lib/systemd/user/default.target.wants && \
  ln -s ../docker.service /usr/lib/systemd/user/default.target.wants/

RUN rm /usr/lib/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist && cp /etc/libccid_Info.plist /usr/lib/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist && \
  rm /usr/lib/systemd/system/sshdgenkeys.service && \
  rm /usr/lib/systemd/system/docker* && \
  ( ! test -f /etc/dbus-1/system.d/wpa_supplicant.conf ||  mv /etc/dbus-1/system.d/wpa_supplicant.conf /usr/share/dbus-1/system.d/ ) && \
  ln -s /mnt/cidata/fwupdx64.efi.signed /usr/lib/fwupd/efi/fwupdx64.efi.signed

RUN rsync --ignore-existing -av /etc/systemd/ /usr/lib/systemd/


RUN plymouth-set-default-theme -R dark-arch

RUN build-initramfs /boot/initramfs-dracut.img

RUN mv /opt /usr/local/opt

ARG VERS=dev
RUN update-os-id-vers desktop $VERS

FROM base AS k8s
RUN pacman -Sy --needed --noconfirm \
  dhcpcd \
  openssh \
  nfs-utils \
  grub \
  ebtables \
  ethtool \
  socat \
  nfs-utils \
  linux-lts \
  linux-lts-headers \
  tcpdump

COPY --from=packages /output/build/k8s/packages /packages
RUN pacman -U /packages/* --noconfirm --needed
RUN rm -r /packages
COPY k8s /
RUN for i in \
  etc/environment \
  etc/xdg/ \
  etc/cloud/ \
  etc/security/ \
  etc/ca-certificates/ \
  etc/ssl/ \
  etc/ssh/ \
  etc/pam.d/ \
  etc/profile.d/ \
  etc/bash.bashrc \
  etc/ethertypes \
  etc/netconfig \
  etc/services \
  etc/rpc \
  ; \
do \
  [ -e "/$i" ] && rsync -av /$i /usr/share/factory/$i ; \
done

RUN echo "HostKey /mnt/data/etc/ssh/ssh_host_rsa_key " >> /usr/share/factory/etc/ssh/sshd_config && \
  echo "HostKey /mnt/data/etc/ssh/ssh_host_ecdsa_key">> /usr/share/factory/etc/ssh/sshd_config && \
  echo "HostKey /mnt/data/etc/ssh/ssh_host_ed25519_key" >> /usr/share/factory/etc/ssh/sshd_config && \
  echo "ChallengeResponseAuthentication no" >> /usr/share/factory/etc/ssh/sshd_config && \
  echo "PasswordAuthentication no" >> /usr/share/factory/etc/ssh/sshd_config && \
  echo "PermitRootLogin no" >> /usr/share/factory/etc/ssh/sshd_config && \
  sed -i -e "s|UsePAM .*|UsePAM no|" /usr/share/factory/etc/ssh/sshd_config

RUN mkdir -p /tmp/download
# export CRI_VERSION="$( curl -s https://api.github.com/repos/kubernetes-sigs/cri-tools/releases | jq -r " map(select(.prerelease == false)) | sort_by(.tag_name) | reverse | .[0].tag_name" )" && \
RUN export CRI_URL=$(curl -s https://api.github.com/repos/kubernetes-sigs/cri-tools/releases | jq -r 'map(select(.prerelease == false)) | sort_by(.tag_name) | reverse | .[0].assets | map(select(.name | test("^crictl-.*linux-amd64.tar.gz$"))) |.[0].browser_download_url ') && \
  curl -L $CRI_URL -o /tmp/download/cri.tar.gz && \
  tar zxvf /tmp/download/cri.tar.gz -C /usr/bin && \
  rm -f /tmp/download/cri.tar.gz

#ARG CONTAINERD_VERS=1.3.2
RUN export CONTAINERD_URL=$(curl -s https://api.github.com/repos/containerd/containerd/releases | jq -r 'map(select(.prerelease == false)) | sort_by(.tag_name) | reverse | .[0].assets | map(select(.name | test("^containerd-.*linux-amd64.tar.gz$"))) |.[0].browser_download_url ') && \
  curl -L $CONTAINERD_URL -o /tmp/download/containerd.tar.gz && \
  tar xf /tmp/download/containerd.tar.gz -C /usr && \
  curl -L https://github.com/containerd/containerd/raw/master/containerd.service -o /usr/lib/systemd/system/containerd.service && \
  sed -i -e 's|/usr/local/bin/containerd|/usr/bin/containerd|' /usr/lib/systemd/system/containerd.service && \
  rm /tmp/download/containerd.tar.gz

#ARG KUBE_VERS=1.16.4
RUN export KUBE_VERS="$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases | jq -r " map(select(.prerelease == false)) | sort_by(.tag_name) | reverse | .[0].tag_name")" && \
  curl -L https://dl.k8s.io/$KUBE_VERS/kubernetes-server-linux-amd64.tar.gz -o /tmp/download/kube.tar.gz && \
  tar xf /tmp/download/kube.tar.gz --strip-components=2 -C /usr \
    kubernetes/server/bin/kubelet \
    kubernetes/server/bin/kube-scheduler \
    kubernetes/server/bin/mounter \
    kubernetes/server/bin/apiextensions-apiserver \
    kubernetes/server/bin/kube-proxy \
    kubernetes/server/bin/kubeadm \
    kubernetes/server/bin/kube-controller-manager \
    kubernetes/server/bin/kube-apiserver \
    kubernetes/server/bin/kubectl

#ARG RUNC_VERS=v1.0.0-rc9
RUN cd /tmp/download && \
  curl -s https://api.github.com/repos/opencontainers/runc/releases | jq -r 'map(select(.prerelease == false)) | sort_by(.tag_name) | reverse | .[0].assets[] | .browser_download_url ' | xargs -n 1 curl -OL  && \
  sha256sum -c runc.sha256sum --ignore-missing && \
  mv runc.amd64 /usr/bin/runc && \
  chmod 755 /usr/bin/runc
RUN rm -r /tmp/download

RUN echo \
  mnt-data.mount \
  systemd-networkd.service \
  systemd-resolved.service \
  sshd.service \
  kubelet.service \
  containerd.service \
  cloud-init.service \
  cloud-final.service \
  zfs-import-scan.service \
  | xargs -n 1 systemctl enable

RUN rsync --ignore-existing -av /etc/systemd/ /usr/lib/systemd/

RUN build-initramfs /boot/initramfs-dracut.img
RUN ln -s /mnt/data/opt-cni /opt/cni && ls -lah /opt && ln -s /mnt/data/kube-exec /usr/libexec
RUN mv /opt /usr/local/opt
ARG VERS=dev
RUN update-os-id-vers k8s $VERS
