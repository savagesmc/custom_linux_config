#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
./uninstall.sh
source ${DIR}/functions.sh
install_files
