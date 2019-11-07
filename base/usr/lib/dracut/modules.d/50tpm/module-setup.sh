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
  inst /usr/bin/tpm2_unseal
  inst /usr/bin/sleep
  inst /bin/bash

  inst $moddir/10-extract-key.conf $systemdsystemunitdir/systemd-cryptsetup@cryptroot.service.d/10-get-key-from-tpm.conf

  inst $moddir/get-key-from-tpm /usr/bin/get-key-from-tpm

  dracut_instmods tpm_crb tpm_tis tpm_tis_core tpm rng_core

  inst_libdir_file 'libtss2-tcti-device.so'
}
