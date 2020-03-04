# building an updated dracut, which support better systemd boot
FROM centos AS builder
RUN dnf install -y \
  rpm-build \
  git \
  make \
  asciidoc \
  wget \
  curl \
  dnf-plugins-core
RUN dnf config-manager --set-enabled PowerTools
RUN git clone https://github.com/dracutdevs/dracut.git
WORKDIR /dracut
RUN dnf builddep -y dracut.spec
RUN make rpm
RUN mkdir -p /output && mv *.rpm /output

# building the image
FROM centos
# needed for openvpn
RUN dnf install epel-release -y
RUN dnf install -y \
  squashfs-tools \
  openssh \
  openssh-server \
  iptables \
  iptables-ebtables \
  socat \
  nfs-utils \
  which \
  bc \
  jq \
  rsync \
  lvm2 \
  sudo \
  tpm2-tools \
  tpm2-abrmd \
  mokutil \
  efivar \
  openvpn \
  cloud-init \
  vim \
  kernel \
  systemd \
  NetworkManager \
  e2fsprogs

COPY --from=builder /output /rpms

RUN dnf install /rpms/dracut{,-tools,-network,-squash}-[0-9]*.x86_64.rpm -y --allowerasing && rm -r /rpms

RUN mkdir -p /tmp/download && \
  export CRI_VERSION="$( curl --silent "https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' )" && \
  curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRI_VERSION/crictl-$CRI_VERSION-linux-amd64.tar.gz -o /tmp/download/cri.tar.gz && \
  tar zxvf /tmp/download/cri.tar.gz -C /usr/bin && \
  rm -fr /tmp/download/

ARG CONTAINERD_VERS=1.3.1
RUN mkdir -p /tmp/download && \
  curl -L https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERS/containerd-$CONTAINERD_VERS.linux-amd64.tar.gz -o /tmp/download/containerd.tar.gz && \
  tar xf /tmp/download/containerd.tar.gz -C /usr && \
  curl -L https://github.com/containerd/containerd/raw/master/containerd.service -o /usr/lib/systemd/system/containerd.service && \
  rm -r /tmp/download

ARG KUBE_VERS=1.16.3
RUN mkdir -p /tmp/download && \
  curl -L https://dl.k8s.io/v$KUBE_VERS/kubernetes-server-linux-amd64.tar.gz -o /tmp/download/kube.tar.gz && \
  tar xf /tmp/download/kube.tar.gz --strip-components=2 -C /usr \
    kubernetes/server/bin/kubelet \
    kubernetes/server/bin/kube-scheduler \
    kubernetes/server/bin/mounter \
    kubernetes/server/bin/apiextensions-apiserver \
    kubernetes/server/bin/kube-proxy \
    kubernetes/server/bin/kubeadm \
    kubernetes/server/bin/kube-controller-manager \
    kubernetes/server/bin/hyperkube \
    kubernetes/server/bin/kube-apiserver \
    kubernetes/server/bin/kubectl \
    && rm -r /tmp/download

ARG RUNC_VERS=v1.0.0-rc9
RUN mkdir -p /tmp/download && cd /tmp/download && \
  curl -L https://github.com/opencontainers/runc/releases/download/$RUNC_VERS/runc.amd64 -O && \
  curl -L https://github.com/opencontainers/runc/releases/download/$RUNC_VERS/runc.sha256sum -O && \
  curl -L https://github.com/opencontainers/runc/releases/download/$RUNC_VERS/runc.amd64.asc -O && \
  sha256sum -c runc.sha256sum --ignore-missing && \
  mv runc.amd64 /usr/bin/runc && \
  chmod 755 /usr/bin/runc \
  && rm -r /tmp/download


COPY base /
COPY deploy-kernel.sh /usr/bin/

# Copying items off of etc to usr

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
  ; \
do \
  [ ! -e "/$i" ] || rsync -av /$i /usr/share/factory/$i ; \
done

# moving the host keys to the persistent mount

RUN echo "HostKey /mnt/data/etc/ssh/ssh_host_rsa_key " >> /usr/share/factory/etc/ssh/sshd_config && \
  echo "HostKey /mnt/data/etc/ssh/ssh_host_ecdsa_key">> /usr/share/factory/etc/ssh/sshd_config && \
  echo "HostKey /mnt/data/etc/ssh/ssh_host_ed25519_key" >> /usr/share/factory/etc/ssh/sshd_config

RUN mkdir -p /extra-etc /etc/secureboot

RUN echo \
  mnt-data.mount \
  NetworkManager.service \
  sshd.service \
  kubelet.service \
  containerd.service \
  cloud-init.service \
  cloud-final.service \
  lvm2-monitor.service \
  sshdgenkeys.service \
  | xargs -n 1 systemctl enable

# Moving enabled items from etc to usr

RUN rsync --ignore-existing -av /etc/systemd/ /usr/lib/systemd/

RUN rsync -av /etc/dbus-1/system.d/ /usr/share/dbus-1/system.d/

ARG VERS=dev
RUN update-os-id-vers k8s $VERS
RUN build-initramfs
RUN ln -s /mnt/data/opt-cni /opt/cni && ls -lah /opt && mkdir -p /usr/libexec
RUN mv /opt /usr/local/opt
