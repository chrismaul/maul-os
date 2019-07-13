#!/bin/bash -x
useradd -m -U maulc
sed -i "s|maulc:|$(cat /install/password.key)" /etc/shadow
