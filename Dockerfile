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
FROM centos AS k8s
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
  NetworkManager

COPY --from=builder /output /rpms

RUN dnf install /rpms/dracut{,-tools,-network,-squash}-[0-9]*.x86_64.rpm -y --allowerasing && rm -r /rpms

COPY base /
COPY deploy-kernel.sh /usr/bin/
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
  ; \
do \
  [ ! -e "/$i" ] || rsync -av /$i /usr/share/factory/$i ; \
done

RUN echo "HostKey /mnt/data/etc/ssh/ssh_host_rsa_key " >> /usr/share/factory/etc/ssh/sshd_config && \
  echo "HostKey /mnt/data/etc/ssh/ssh_host_ecdsa_key">> /usr/share/factory/etc/ssh/sshd_config && \
  echo "HostKey /mnt/data/etc/ssh/ssh_host_ed25519_key" >> /usr/share/factory/etc/ssh/sshd_config

RUN mkdir -p /extra-etc /etc/secureboot /tmp/download

RUN export CRI_VERSION="$( curl --silent "https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' )" && \
  curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRI_VERSION/crictl-$CRI_VERSION-linux-amd64.tar.gz -o /tmp/download/cri.tar.gz && \
  tar zxvf /tmp/download/cri.tar.gz -C /usr/bin && \
  rm -f /tmp/download/cri.tar.gz

ARG CONTAINERD_VERS=1.3.1
RUN curl -L https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERS/containerd-$CONTAINERD_VERS.linux-amd64.tar.gz -o /tmp/download/containerd.tar.gz && \
  tar xf /tmp/download/containerd.tar.gz -C /usr && \
  curl -L https://github.com/containerd/containerd/raw/master/containerd.service -o /usr/lib/systemd/system/containerd.service && \
  rm /tmp/download/containerd.tar.gz

ARG KUBE_VERS=1.16.3
RUN curl -L https://dl.k8s.io/v$KUBE_VERS/kubernetes-server-linux-amd64.tar.gz -o /tmp/download/kube.tar.gz && \
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
    kubernetes/server/bin/kubectl

ARG RUNC_VERS=v1.0.0-rc9
RUN cd /tmp/download && \
  curl -L https://github.com/opencontainers/runc/releases/download/$RUNC_VERS/runc.amd64 -O && \
  curl -L https://github.com/opencontainers/runc/releases/download/$RUNC_VERS/runc.sha256sum -O && \
  curl -L https://github.com/opencontainers/runc/releases/download/$RUNC_VERS/runc.amd64.asc -O && \
  sha256sum -c runc.sha256sum --ignore-missing && \
  mv runc.amd64 /usr/bin/runc && \
  chmod 755 /usr/bin/runc
RUN rm -r /tmp/download

RUN echo \
  mnt-data.mount \
  NetworkManager.service \
  sshd.service \
  kubelet.service \
  containerd.service \
  cloud-init.service \
  cloud-final.service \
  lvm2-monitor.service \
  | xargs -n 1 systemctl enable

RUN rsync --ignore-existing -av /etc/systemd/ /usr/lib/systemd/

RUN rsync -av /etc/dbus-1/system.d/ /usr/share/dbus-1/system.d/

ARG VERS=dev
RUN update-os-id-vers k8s $VERS
RUN build-initramfs
RUN ln -s /mnt/data/opt-cni /opt/cni && ls -lah /opt && mkdir -p /usr/libexec
RUN mv /opt /usr/local/opt
