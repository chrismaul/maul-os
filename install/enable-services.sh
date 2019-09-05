#!/bin/bash
for i in $(cat /install/packages.txt  | grep -v "^#" | grep -v "^ *\$")
do
  systemctl enable $i
done
