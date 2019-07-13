#!/bin/bash
CURDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
rsync -av $CURDIR/../home/ $HOME/