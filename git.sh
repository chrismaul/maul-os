#!/bin/bash
git config --global --add remote.upstream.fetch "+refs/pull/*/head:refs/remotes/upstream/pr/*"
git config --global push.default current
git config --global commit.gpgsign true

# gpg -import
# https://help.github.com/articles/telling-git-about-your-gpg-key/

git config --global user.email "maulc@us.ibm.com"
git config --global user.name "CHRISTOPHER A. MAUL"
if uname -o | grep -iq linux
then
  git config --global core.editor "vim"
  git config --global diff.tool meld
  git config --global difftool.prompt false
fi
