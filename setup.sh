#!/usr/bin/env bash

# Copyright 2017 Mycroft AI Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

######################################################
# @author sean.fitzgerald (aka clusterfudge)
#
# The purpose of this script is to create a self-
# contained development environment using
# virtualenv for python dependency sandboxing.
# This script will create a virtualenv (using the
# conventions set by virtualenv-wrapper for
# location and naming) and install the requirements
# laid out in requirements.txt, pocketsphinx, and
# pygtk into the virtualenv. Mimic will be
# installed and built from source inside the local
# checkout.
#
# The goal of this script is to create a development
# environment in user space that is fully functional.
# It is expected (and even encouraged) for a developer
# to work on multiple projects concurrently, and a
# good OSS citizen respects that and does not pollute
# a developers workspace with it's own dependencies
# (as much as possible).
# </endRant>
######################################################

# exit on any error
set -Ee

show_help() {
        echo "setup.sh: Jasper development environment setup"
        echo "Usage: setup.sh [options]"
        echo
        echo "Options:"
        echo "    -r, --allow-root  Allow to be run as root (e.g. sudo)"
        echo "    -h, --help        Show this message"
        echo
        echo "This will prepare your environment for running Jasper"
        echo "services. Normally this should be run as a normal user,"
        echo "not as root/sudo."
}

opt_allowroot=false

for var in "$@"
do
    if [[ ${var} == "-h" ]] || [[ ${var} == "--help" ]] ; then
        show_help
        exit 0
    fi

    if [[ ${var} == "-r" ]] || [[ ${var} == "--allow-root" ]] ; then
        opt_allowroot=true
    fi
done

if [ $(id -u) -eq 0 ] && [ "${opt_allowroot}" != true ] ; then
  echo "This script should not be run as root or with sudo."
  echo "To force, rerun with --allow-root"
  exit 1
fi

found_exe() {
    hash "$1" 2>/dev/null
}

install_deps() {
    echo "Installing packages..."
    if found_exe sudo; then
        SUDO=sudo
    fi

    if found_exe apt-get; then
        $SUDO apt-get install -y python python-dev python-setuptools python-virtualenv virtualenvwrapper bison libasound2-dev libportaudio-dev python-pyaudio libmad libmad-dev
    elif found_exe yum; then
        $SUDO yum install -y python python-devel python-pip python-setuptools python-virtualenv python-virtualenvwrapper bison alsa-lib-devel portaudio-devel libmad libmad-devel
    else
        if found_exe tput; then
            green="$(tput setaf 2)"
            blue="$(tput setaf 4)"
            reset="$(tput sgr0)"
        fi
        echo
        echo "${green}Could not find package manager"
        echo "${green}Make sure to manually install:${blue} python python-setuptools python-virtualenv virtualenvwrapper bison alsa-lib portaudio libmad "
        echo $reset
    fi
}

install_deps

TOP=$(cd $(dirname $0) && pwd -L)

if [ -z "$WORKON_HOME" ]; then
    VIRTUALENV_ROOT=${VIRTUALENV_ROOT:-"${HOME}/.virtualenvs/Jasper"}
else
    VIRTUALENV_ROOT="$WORKON_HOME/Jasper"
fi

# create virtualenv, consistent with virtualenv-wrapper conventions
if [ ! -d "${VIRTUALENV_ROOT}" ]; then
   mkdir -p $(dirname "${VIRTUALENV_ROOT}")
  virtualenv -p python2.7 "${VIRTUALENV_ROOT}"
fi
source "${VIRTUALENV_ROOT}/bin/activate"
cd "${TOP}"
easy_install pip
pip install --upgrade virtualenv

# Add Jasper to the virtualenv path
# (This is equivalent to typing 'add2virtualenv $TOP', except
# you can't invoke that shell function from inside a script)
#VENV_PATH_FILE="${VIRTUALENV_ROOT}/lib/python2.7/site-packages/_virtualenv_path_extensions.pth"
#if [ ! -f "$VENV_PATH_FILE" ] ; then
#    echo "import sys; sys.__plen = len(sys.path)" > "$VENV_PATH_FILE" || return 1
#    echo "import sys; new=sys.path[sys.__plen:]; del sys.path[sys.__plen:]; p=getattr(sys,'__egginsert',0); sys.path[p:p]=new; sys.__egginsert = p+len(new)" >> "$VENV_PATH_FILE" || return 1
#fi
#
#if ! grep -q "Jasper" $VENV_PATH_FILE; then
#   echo "Adding Jasper to virtualenv path"
#   sed -i.tmp '1 a\
#'"$TOP"'
#' "${VENV_PATH_FILE}"
#fi

# install requirements (except pocketsphinx)
# removing the pip2 explicit usage here for consistency with the above use.

if ! pip install -r requirements.txt; then
    echo "Warning: Failed to install all requirements. Continue? y/N"
    read -n1 continue
    if [[ "$continue" != "y" ]] ; then
        exit 1
    fi
fi

#build and install pocketsphinx
#cd ${TOP}
#${TOP}/scripts/install-pocketsphinx.sh -q
#build and install mimic

# run config script
echo -e "\n"
python ${TOP}/client/populate.py

cd "${TOP}"
