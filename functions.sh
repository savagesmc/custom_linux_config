#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

files=(myvimrc_vundle_plugins myvimrc mygitconfig myzshrc mytmux.conf)

function install_files()
{
    for f in ${files[@]}
    do
        ln -sf ${DIR}/${f} ~/.${f}
    done
}

function remove_files()
{
    for f in ${files[@]}
    do
        rm -f ~/.${f}
    done
}
