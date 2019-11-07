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
  inst /usr/lib/systemd/systemd-veritysetup
  inst $systemdutildir/system-generators/systemd-veritysetup-generator
  dracut_instmods dm-verity
}
