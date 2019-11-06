#!/bin/bash

# called by dracut
check() {
    # No point trying to support lvm if the binaries are missing
    return 0
}

# called by dracut
depends() {
    # We depend on dm_mod being loaded
    echo systemd
    return 0
}



# called by dracut
install() {
    inst rsync
    inst setup-customize

    test -d /extra-etc && rsync -av /extra-etc/ $initdir/extra-etc/
    inst_multiple -o \
        $systemdsystemunitdir/setup-customize-initrd.service \
        $systemdsystemunitdir/initrd-switch-root.target.wants/setup-customize-initrd.service \
        $systemdsystemunitdir/setup-profile-home.service \
        $systemdsystemunitdir/initrd-switch-root.target.wants/setup-profile-home.service

}
