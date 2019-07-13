FROM archlinux/base
COPY . /install
WORKDIR /install/setup/arch/install
RUN ./install-packages.sh
RUN ./enable-services.sh
RUN ./mod-user.sh
