#!/bin/sh

### LICENSE - (BSD 2-Clause) // ###
#
# Copyright (c) 2015, Daniel Plominski (Plominski IT Consulting)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
### // LICENSE - (BSD 2-Clause) ###

### ### ### PLITC // ### ### ###

### stage0 // ###
#
#// variables - source jail
SOURCEHOST="freebsd"
SOURCEJAIL="srs1"
SOURCESNAPSHOTSUFFIX="_MIGRATION_"

#// variables - target jail
TARGETHOST="freenas"
TARGETJAIL="plone"
TARGETSNAPSHOTSUFFIX="_MIGRATION_"
TARGETPACKAGE=""

#// variables (generic purpose)
OSVERSION=$(uname)
if [ "$OSVERSION" = "FreeBSD" ]; then :; else echo "[ERROR] Plattform = unknown"; exit 1; fi
FREENAS=$(uname -a | grep -c "ixsystems.com")
JAILED=$(sysctl -a | grep -c "security.jail.jailed: 1")
MYNAME=$(whoami)
DATE=$(date +%Y%m%d-%H%M)
HOSTMACHINE=$(hostname)
#
### // stage0 ###

### stage1 // ###
#
#// functions (generic purpose)

PRG="$0"
#// need this for relative symlinks
while [ -h "$PRG" ] ;
do
   PRG=$(readlink "$PRG")
done
DIR=$(dirname "$PRG")

ADIR="$PWD"

#// function: spinner
spinner()
{
   local pid=$1
   local delay=0.01
   local spinstr='|/-\'
   while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
         local temp=${spinstr#?}
         printf " [%c]  " "$spinstr"
         local spinstr=$temp${spinstr%"$temp"}
         sleep $delay
         printf "\b\b\b\b\b\b"
   done
   printf "    \b\b\b\b"
}

#// function: cleanup tmp
cleanup(){
   rm -rf /tmp/easy_dtrace*
}

#// function: pkg installation
packageinstall(){
   #/ check package
   CHECKPKG=$(pkg info | grep -c "$@")
   if [ "$CHECKPKG" = "0" ]
   then
      #/ check ports
      CHECKPORTS=$(find /usr/ports -name "$@" | grep -c "$@")
      if [ "$CHECKPORTS" = "0" ]
      then
         pkg update
         pkg install -y "$@"
         if [ $? -eq 0 ]
         then
            : # dummy
         else
            echo "[ERROR] something went wrong, can't install the package"
            exit 1
         fi
      else
         portsnap update
         if [ $? -eq 0 ]
         then
            : # dummy
         else
            echo "[ERROR] something went wrong, can't install the package"
            exit 1
         fi
         GETPATH=$(find /usr/ports -maxdepth 2 -mindepth 2 -name "$@" | tail -n 1)
         cd "$GETPATH" && make install clean
         if [ $? -eq 0 ]
         then
            : # dummy
         else
            echo "[ERROR] something went wrong, can't install the package"
            exit 1
         fi
      fi
   else
      : # dummy
   fi
}

#// function: check root user
checkroot(){
if [ "$MYNAME" = "root" ]
then
   : # dummy
else
   echo "[ERROR] You must be root to run this script"
   exit 1
fi
}

#// function: check jailed
checkjailed(){
if [ "$JAILED" = "0" ]
then
   : # dummy
else
   echo "[ERROR] Run this script on the FreeBSD HOST"
   exit 1
fi
}

#// function: check freenas
checkfreenas(){
if [ "$FREENAS" = "1" ]
then
   echo "[ERROR] FreeBSD only support"
   exit 1
else
   : # dummy
fi
}

#// function: check read
checkread(){
if [ -z "$@" ]; then
   echo "[ERROR] nothing selected"
   exit 1
fi
}

#// function: show shell info
show(){
   printf "\033[1;33m%s\033[0m\n" "$@"
}
### // stage0 ###

case "$1" in
'source')
### stage1 // ###
#
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###

show "test 123"
#/ pkg install: ksh93
#(pkginstall ksh93) & spinner $!

### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
cleanup
### ### ### ### ### ### ### ### ###
echo "" # printf
printf "\033[1;31mMigration for Plone finished.\033[0m\n"
### ### ### ### ### ### ### ### ###
#
### // stage1 ###
   ;;
'target')
### stage1 // ###
#
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###

#/ pkg install: ksh93
#(pkginstall ksh93) & spinner $!

### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
cleanup
### ### ### ### ### ### ### ### ###
echo "" # printf
printf "\033[1;31mMigration for Plone finished.\033[0m\n"
### ### ### ### ### ### ### ### ###
#
### // stage1 ###
   ;;
*)
printf "\033[1;31mWARNING: migration_plone is experimental and its not ready for production. Do it at your own risk.\033[0m\n"
echo "" # usage
echo "usage: $0 { source | target }"
;;
esac
exit 0
### ### ### PLITC ### ### ###
# EOF
