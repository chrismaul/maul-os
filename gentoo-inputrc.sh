#!/usr/bin/env bash
cat > /etc/inputrc << EOF 
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": history-search-backward
"\e[6~": history-search-forward
"\e[3~": delete-char
"\e[2~": quoted-insert
"\e[5C": forward-word
"\e[5D": backward-word
"\e\e[C": forward-word
"\e\e[D": backward-word
set completion-ignore-case On
EOF