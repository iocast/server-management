#!/usr/bin/env bash

<<-'LICENSE'
The MIT License (MIT)

Copyright (c) 2014 iocast

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE


VERSION=0.1
AUTHOR="iocast"
MAIL="iocast@me.com"
INITIALIZATION="$0 initialize --destination server.exmaple.com"
USAGE="$0 backup --node server.exmaple.com"


usage() {
cat <<- EOF
usage: $0 [initialize|backup] [OPTIONS]

OPTIONS:
-d | --destination    DESTINATION        to server to which you want to backup
-h | --help                              help text
     --version                           prints the version information

EXAMPLE:
$USAGE

WORKFLOW:
This script should be run as root because it will mount network shares.

Run $INITIALIZATION to initialize a configuration file called .smbcredentials_server.example.com which will be stored under the home directory of the current user. After this file has been created you can run the backup $USAGE. Note that you need to run the backup under the same user as the initialization script.

To run in periodical, you can create a crontab entry, e.g. 5 min past 4 in the morning:

# m h dom mon dow user  command
05 4    * * *   root    /opt/backup_over_cifs.sh backup --destination server.example.com

EOF
}


version() {
cat <<- EOF
version $VERSION by $AUTHOR licenced under MIT
EOF
}



TASK=
DEST=

i=0
while (($#)); do
	OPT=$1
	shift
	case $OPT in
		--*)
		case ${OPT:2} in
			destination) DEST="$1"; shift;;
			version) version; exit 1;;
			help) usage; exit 1;;
		esac;;
		-*)
		case ${OPT:1} in
			d) DEST="$1"; shift;;
			h) usage; exit 1;;
		esac;;
		*)
		TASK="$OPT"
		let i+=1
	esac
done


if [ $TASK = "initialize" ]; then
	read -p "Enter the share point on the destination '$DEST': " -e sharepoint
	read -p "Enter the mount point: " -e mountpoint
	read -p "Folders to backup: " -e folders
	
	read -p "What is your username [`whoami`]? " -e username
	username="${username:-`whoami`}"
	read -p "Please enter the password for user '$username': " -s password
	echo ""
	
	echo "creating password file at '$HOME/.smbcredentials_$DEST'"
	
	echo "username=$username" > $HOME/.smbcredentials_$DEST
	echo "password=$password" >> $HOME/.smbcredentials_$DEST
	echo "sharepoint=$sharepoint" >> $HOME/.smbcredentials_$DEST
	echo "mountpoint=$mountpoint" >> $HOME/.smbcredentials_$DEST
	echo "folders=\"$folders\"" >> $HOME/.smbcredentials_$DEST
	
	chmod 0600 $HOME/.smbcredentials_$DEST
	
	exit 0
fi

if [ $TASK = "backup" ]; then
	source $HOME/.smbcredentials_$DEST
	
	if [ ! -d "$mountpoint" ]; then
		mkdir -p $mountpoint
	fi
	
	mount -t cifs -o credentials=$HOME/.smbcredentials_$DEST //$DEST$sharepoint $mountpoint
	
	if [ ! -d "$mountpoint/$(`hostname`)" ]; then
		mkdir -p $mountpoint/$(hostname)
	fi
	
	for folder in $folders
	do
		rsync -av --delete $folder $mountpoint/$(hostname)
	done
	umount $mountpoint
	
	exit 0
fi

usage
exit 1
