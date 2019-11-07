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
    inst /usr/lib/systemd/systemd-sulogin-shell

    inst /usr/bin/sulogin

    inst systemctl
    inst blkid
    inst journalctl
    inst kmod


    inst "$(readlink -f /usr/lib/libnss_files.so)"
    printf '%s\n' >"$initdir/etc/nsswitch.conf" \
        'passwd: files' \
        'group: files' \
        'shadow: files'

    echo "root:x:0:0:root:/:/bin/bash" >"$initdir/etc/passwd"
    echo "root:x:0:root" >"$initdir/etc/group"
    echo "root::::::::" >"$initdir/etc/shadow"

    touch $initdir/etc/initrd-release

    rm $initdir/$systemdsystemunitdir/systemd-tmpfiles-setup.service $initdir/$systemdsystemunitdir/sysinit.target.wants/systemd-tmpfiles-setup.service

    inst_multiple \
        $systemdsystemunitdir/emergency.service \
        $systemdsystemunitdir/emergency.target \
        $systemdsystemunitdir/rescue.target \
        $systemdsystemunitdir/rescue.service
}
