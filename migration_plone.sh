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
ADIR="$PWD"
#
#// include settings config
if [ -e "$ADIR"/config/settings.conf ]; then :; else printf "\033[1;31mERROR: can't find config/settings.conf!\033[0m\n"; exit 1; fi
. "$ADIR"/config/settings.conf
#
#// variables (generic purpose)
OSVERSION=$(uname)
if [ "$OSVERSION" = "FreeBSD" ]; then :; else printf "\033[1;31mERROR: Plattform = unknown\033[0m\n"; exit 1; fi
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
   rm -rf /tmp/migration_plone*
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
            #/echo "[ERROR] something went wrong, can't install the package"
            printf "\033[1;31mERROR: something went wrong, can't install the package!\033[0m\n"
            exit 1
         fi
      else
         portsnap update
         if [ $? -eq 0 ]
         then
            : # dummy
         else
            #/echo "[ERROR] something went wrong, can't install the package"
            printf "\033[1;31mERROR: something went wrong, can't install the package!\033[0m\n"
            exit 1
         fi
         GETPATH=$(find /usr/ports -maxdepth 2 -mindepth 2 -name "$@" | tail -n 1)
         cd "$GETPATH" && make install clean
         if [ $? -eq 0 ]
         then
            : # dummy
         else
            #/echo "[ERROR] something went wrong, can't install the package"
            printf "\033[1;31mERROR: something went wrong, can't install the package!\033[0m\n"
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
   #/echo "[ERROR] You must be root to run this script"
   printf "\033[1;31mERROR: You must be root to run this script!\033[0m\n"
   exit 1
fi
}

#// function: check jailed
checkjailed(){
if [ "$JAILED" = "0" ]
then
   : # dummy
else
   #/echo "[ERROR] Run this script on the FreeBSD HOST"
   printf "\033[1;31mERROR: Run this script on the FreeBSD HOST!\033[0m\n"
   exit 1
fi
}

#// function: check freenas
checkfreenas(){
if [ "$FREENAS" = "1" ]
then
   #/echo "[ERROR] FreeBSD only support"
   printf "\033[1;31mERROR: FreeBSD only support!\033[0m\n"
   exit 1
else
   : # dummy
fi
}

#// function: check read
checkploneversion(){
if [ -z "$@" ]; then
   #/echo "[ERROR]"
   printf "\033[1;31mERROR: Plone Version in config/settings.conf undefined!\033[0m\n"
   exit 1
fi
}

#// function: check read
checkread(){
if [ -z "$@" ]; then
   #/echo "[ERROR] nothing selected"
   printf "\033[1;31mERROR: nothing selected!\033[0m\n"
   exit 1
fi
}

#// function: showyellow shell info (green)
showgreen(){
   printf "\033[1;32m%s\033[0m\n" "$@"
}

#// function: showyellow shell info (yellow)
showyellow(){
   printf "\033[1;33m%s\033[0m\n" "$@"
}

#// function: showyellow shell info (red)
showred(){
   printf "\033[1;31m%s\033[0m\n" "$@"
}

#// function: source jail id
sjailid(){
   #/jls | grep "$SOURCEJAIL" | awk '{print $1}' # dirty
   jls | grep -w "$SOURCEJAIL" | grep -E '(^| )'"$SOURCEJAIL"'( |$)' | awk '{print $1}'
}

#// function: source jail match
sjailmatch(){
   #/SMATCH=$(jls | grep "$SOURCEJAIL" | awk '{print $4}') # dirty
   #/zfs list | grep -w "$SMATCH" | awk '{print $1}' # dirty
   SMATCH=$(jls | grep -w "$SOURCEJAIL" | grep -E '(^| )'"$SOURCEJAIL"'( |$)' | awk '{print $4}')
   zfs list | grep -w "$SMATCH" | grep -E '(^| )'"$SMATCH"'( |$)' | awk '{print $1}'
}

#// function: target jail id
tjailid(){
   jls | grep -w "$TARGETJAIL" | grep -E '(^| )'"$TARGETJAIL"'( |$)' | awk '{print $1}'
}

#// function: target jail match
tjailmatch(){
   TMATCH=$(jls | grep -w "$TARGETJAIL" | grep -E '(^| )'"$TARGETJAIL"'( |$)' | awk '{print $4}')
   zfs list | grep -w "$TMATCH" | grep -E '(^| )'"$TMATCH"'( |$)' | awk '{print $1}'
}

#// function: check ping
checkping(){
   ping -q -c5 "$@" > /dev/null
   if [ $? -eq 0 ]
   then
      : # dummy
   else
      #/echo "[ERROR] server isn't responsive!"
      printf "\033[1;31mERROR: server isn't responsive!\033[0m\n"
      exit 1
   fi
}

#// function: check zfs recv
checkzfsrecv(){
   CHECKZFSRECV=$(ps -ax | grep -c "zfs recv [$TARGETZFSRECEIVE]")
   if [ "$CHECKZFSRECV" = "0" ]
   then
      : # dummy
   else
      #/echo "[ERROR] please wait until the zfs send & receive transfer is complete"
      printf "\033[1;31mERROR: Please wait until the zfs send & receive transfer is complete!\033[0m\n"
      exit 1
   fi
}

#// function: plone backup transfer
plonetransmit(){
   TBKPATH=$(zfs list | grep -w "$TARGETZFSRECEIVE" | awk '{print $5}')
   TBKMATCH=$(jls | grep -w "$TARGETJAIL" | grep -E '(^| )'"$TARGETJAIL"'( |$)' | awk '{print $4}')
   cp -rf "$TBKPATH""$SOURCEPLONEDIR" "$TBKMATCH""$TARGETPLONEDIR"
   if [ $? -eq 0 ]
   then
      : # dummy
   else
      #/echo "[ERROR]"
      printf "\033[1;31mERROR: can't copy old plone data to the new jail!\033[0m\n"
      exit 1
   fi
}

#// function: new jail path
newjailpath(){
   jls | grep -w "$TARGETJAIL" | grep -E '(^| )'"$TARGETJAIL"'( |$)' | awk '{print $4}'
}
#
### // stage0 ###

case "$1" in
'source')
### stage1 // ###
#
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###

#/ stop (old) plone
showyellow "stop plone for: $SOURCEJAIL"
jexec "$(sjailid)" /usr/local/etc/rc.d/plone stop
jexec "$(sjailid)" /bin/sync
(sleep 4) & spinner $!

#/ take snapshot
showyellow "zfs snapshot for: $SOURCEJAIL"
zfs snapshot "$(sjailmatch)"@"$SOURCESNAPSHOTSUFFIX""$DATE"
(sleep 4) & spinner $!

#/ start (old) plone
showyellow "start plone for: $SOURCEJAIL"
jexec "$(sjailid)" /usr/local/etc/rc.d/plone start
jexec "$(sjailid)" /bin/sync
(sleep 4) & spinner $!

#/ prepare zfs send & receive
echo "" # dummy
echo "ping test to remote host: $TARGETHOST"
echo "" # dummy
checkping "$TARGETHOST"
(sleep 4) & spinner $!

#/ zfs send & receive
showyellow "enter the password for the remote host zfs send & receive transmission"
#/zfs send "$(sjailmatch)"@"$SOURCESNAPSHOTSUFFIX""$DATE" | ssh -p "$TARGETSSHPORT" "$TARGETSSHUSER"@"$TARGETHOST" zfs recv -F "$TARGETZFSRECEIVE"
zfs send "$(sjailmatch)"@"$SOURCESNAPSHOTSUFFIX""$DATE" | ssh -p "$TARGETSSHPORT" "$TARGETSSHUSER"@"$TARGETHOST" zfs recv "$TARGETZFSRECEIVE"
if [ $? -eq 0 ]
then
   : # dummy
else
   #/echo "[ERROR] zfs send & receive failed!"
   printf "\033[1;31mERROR: zfs send & receive failed!\033[0m\n"
   exit 1
fi
(sleep 4) & spinner $!

### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
cleanup
### ### ### ### ### ### ### ### ###
echo "" # printf
printf "\033[1;32mMigration for (source) Plone finished.\033[0m\n"
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

#/ check zfs send & receive transmission
showyellow "check zfs send & recv for: $TARGETJAIL"
checkzfsrecv
(sleep 4) & spinner $!

#/ check defined plone version
checkploneversion "$TARGETPLONEVERSION"
(sleep 4) & spinner $!

#/ do rollback
showyellow "zfs rollback for: $TARGETJAIL"
zfs rollback "$(tjailmatch)"@"$TARGETZFSROLLBACK"
(sleep 4) & spinner $!

#/ jail (base) update
showyellow "jail update for: $TARGETJAIL"
jexec "$(tjailid)" pkg update
(sleep 4) & spinner $!

#/ jail (base) upgrade
showyellow "jail upgrade for: $TARGETJAIL"
jexec "$(tjailid)" pkg upgrade -y
(sleep 4) & spinner $!

if [ "$TARGETPLONEVERSION" = "4" ]
then
   #/ install plone 4
   showyellow "install plone for: $TARGETJAIL"
   jexec "$(tjailid)" pkg install -y plone wv xpdf freetype2 ltxml
   (sleep 4) & spinner $!

   #/ fix: libiconv.so
   jexec "$(tjailid)" ln -s /usr/local/lib/libiconv.so.3 /usr/local/lib/libiconv.so.2

   #/ fix: libutil.so
   jexec "$(tjailid)" ln -s /lib/libutil.so.9 /lib/libutil.so.8

   #/ fix: libz.so
   jexec "$(tjailid)" ln -s /lib/libz.so.6 /lib/libz.so.5

   #/ plone backup file transfer
   showyellow "copy old plone files to the new jail: $TARGETJAIL ... in 5 seconds ... (it will take a long time)"
   (sleep 5) & spinner $!
   jexec "$(tjailid)" mkdir -p /usr/local/www
   (plonetransmit) & spinner $!
   jexec "$(tjailid)" chown -R www:www "$TARGETPLONEDIR"
   (sleep 4) & spinner $!

   #/ create new zope instance
   showyellow "create an new zope instance for: $TARGETJAIL"
   jexec "$(tjailid)" /usr/local/bin/mkzopeinstance --dir /usr/local/www/Zope213/
   jexec "$(tjailid)" chown -R www:www /usr/local/www/Zope213/var
   jexec "$(tjailid)" chown -R www:www /usr/local/www/Zope213/log
   (sleep 4) & spinner $!

   #/ move plone datastorage
   showyellow "move plone datastorage files"
   jexec "$(tjailid)" mv -f "$TARGETPLONEDIR"/zinstance/var /usr/local/www/Zope213
   jexec "$(tjailid)" chown -R www:www /usr/local/www/Zope213/var
   (sleep 4) & spinner $!

   #/ define zope service
   showyellow "define zope service for: $TARGETJAIL"
   jexec "$(tjailid)" sysrc zope213_enable="YES"
   jexec "$(tjailid)" sysrc zope213_instances="/usr/local/www/Zope213"
   jexec "$(tjailid)" cp -f /usr/local/www/Zope213/etc/zope.conf /usr/local/www/Zope213/etc/zope.conf.default
   (sleep 4) & spinner $!

   #/ define zope config
   showyellow "define zope config for: $TARGETJAIL"
   #/jexec "$(tjailid)" cat << "ZOPECONFIG" > /usr/local/www/Zope213/etc/zope.conf
   cat << "ZOPECONFIG" > /tmp/migration_plone_zope.conf
### ### ### ZOPE // ### ### ###

%define INSTANCE /usr/local/www/Zope213
instancehome $INSTANCE
effective-user www

<eventlog>
  level info
  <logfile>
    path $INSTANCE/log/event.log
    level info
  </logfile>
</eventlog>

<logger access>
  level WARN
  <logfile>
    path $INSTANCE/log/Z2.log
    format %(message)s
  </logfile>
</logger>

<http-server>
  # valid keys are "address" and "force-connection-close"
  address 8080

  # force-connection-close on
  #
  # You can also use the WSGI interface between ZServer and ZPublisher:
  # use-wsgi on
  #
  # To defer the opening of the HTTP socket until the end of the
  # startup phase:
  # fast-listen off
</http-server>

<zodb_db main>
  # Main FileStorage database
  <filestorage>
    # See .../ZODB/component.xml for directives (sectiontype
    # "filestorage").
    path $INSTANCE/var/filestorage/Data.fs
  </filestorage>
  mount-point /
</zodb_db>

<zodb_db temporary>
  # Temporary storage database (for sessions)
  <temporarystorage>
    name temporary storage for sessioning
  </temporarystorage>
  mount-point /temp_folder
  container-class Products.TemporaryFolder.TemporaryContainer
</zodb_db>

### ### ### // ZOPE ### ### ###
# EOF
ZOPECONFIG
   cp -f /tmp/migration_plone_zope.conf "$(newjailpath)"/usr/local/www/Zope213/etc/zope.conf
   (sleep 4) & spinner $!

   #/ start zope
   showyellow "start zope service for: $TARGETJAIL"
   jexec "$(tjailid)" service zope213 start
   (sleep 4) & spinner $!



   #/ finished!
   showgreen "Migration finished"
   exit 0
fi

if [ "$TARGETPLONEVERSION" = "5" ]
then
   #/ install plone 5
   showyellow "currently not supported"
   exit 1

   #/ finished!
   showgreen "Migration finished"
   exit 0
else
   #/ unsupported plone
   showred "unsupported plone version defined"
   exit 1
fi

### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
### ### ### ### ### ### ### ### ###
cleanup # useless
### ### ### ### ### ### ### ### ###
echo "" # printf
printf "\033[1;32mMigration for (target) Plone finished.\033[0m\n"
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
