FROM archlinux/base
COPY install /install
RUN /install/install-packages.sh
#RUN ./enable-services.sh
#RUN ./mod-user.sh
COPY files /
