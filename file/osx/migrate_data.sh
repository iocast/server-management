#!/bin/bash

#  folder_size.sh
#  file-server-management
#

<<-'LICENSE'
The MIT License (MIT)

Copyright (c) 2013 iocast

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


<<-'CONDITIONS'
Dependencies:
-------------
- jq >= 1.3 (source: http://stedolan.github.io/jq/)
- functions.sh (same project)

Configuration:
--------------
1) create a ssh key on the server where you run this script
|- a) cd ~/.ssh/
|- b) ssh-keygen
|- c) cat ~/.ssh/id_rsa.pub
|- d) copy the public key to the clipboard

2) login to other server
|- a) paste it to vim ~/.ssh/authorized_keys

3) change rsync rights
|- a) sudo visudo
|- b) add <user> ALL= NOPASSWD:/usr/bin/rsync
CONDITIONS

# IMPORTS
. ./libs/functions.sh

VERSION=0.2
AUTHOR="iocast"
MAIL="iocast@me.com"
USAGE="sudo $0 -c shares.json -e excludes.txt"


DATE=`date +"%Y-%m-%d_%H-%M"`
MAX_RETRIES=2

ADDITIONS=
CONFIG=
EXCLUDES=

RSA=

source_uri=
source_user=

destination_uri=
destination_user=
destination_group=
destination_modus=


function usage() {
cat <<- EOF
usage: $0 [OPTIONS]

OPTIONS:
-c | --config           CONFIG            path to the json config file
-e | --exclude          EXCLUDE           path to the exclude file
-h | --help                               show this message
     --version                            prints the version information

INFORMATION:
Currently only a ssh connection over RSA to the source server is ssupported.
Thus you have first to generate a RSA key using ssh-keygen and install the
public key on the source server.

DEPENDENCIES:
- permisson_propagation.sh

EXAMPLE:
$USAGE
EOF
}

function version() {
cat <<- EOF
version $VERSION by $AUTHOR licences under MIT
EOF
}


function synchronize() {
	echo "trying to sync $source_uri$1 to $destination_uri"
	
	while [ 1 ]
	do
		rsync -rltDz --delete -e "ssh -l $destination_user -i $RSA -o StrictHostKeyChecking=no" --rsync-path="sudo rsync" --chmod="$destination_modus_rsync" --exclude-from="$EXCLUDES" --stats "$source_user@$source_uri$1" "$destination_uri"
		if [[ $? == 0 || $? == 12 ]] ; then
			break
		fi
		sleep 900
	done
}


i=0
while (($#)); do
	OPT=$1
	shift
	case $OPT in
		--*)
		case ${OPT:2} in
			config) CONFIG="$1"; shift;;
			exclude) EXCLUDES="$1"; shift;;
			version) version; exit 1;;
			help) usage; exit 1;;
		esac;;
		-*)
		case ${OPT:1} in
			c) CONFIG="$1"; shift;;
			e) EXCLUDES="$1"; shift;;
			h) usage; exit 1;;
		esac;;
		*)
		ADDITIONS[i]="$OPT"
		let i+=1
	esac
done


# check if mandatory variables are set
if [[ -z $CONFIG ]] || [[ -z $EXCLUDES ]] ; then
	echo "please use a OPTION as follow:"
	echo ""
	usage
	exit 1
fi


# setup environment

RSA="`cat ${CONFIG} | ./libs/jq -r '.rsa'`"

source_uri="`cat ${CONFIG} | ./libs/jq -r '.source.uri'`"
source_user="`cat ${CONFIG} | ./libs/jq -r '.source.user'`"
destination_uri="`cat ${CONFIG} | ./libs/jq -r '.destination.uri'`"
destination_user="`cat ${CONFIG} | ./libs/jq -r '.destination.user'`"
destination_group="`cat ${CONFIG} | ./libs/jq -r '.destination.group'`"
destination_modus_rsync="`cat ${CONFIG} | ./libs/jq -r '.destination.modus.rsync'`"
destination_modus_chmod="`cat ${CONFIG} | ./libs/jq -r '.destination.modus.chmod'`"

echo "syncing from $source_uri to $destination_uri"
echo ""


# echoing short information table
echo "following tasks to be done"
echo ""
printf "+----------------------------------------------------+---------------------------------------------------+\n"
printf "| from: %-44s | to: %-45s |\n" "$source_uri" "$destination_uri"
printf "+----------------------------------------------------+------+------------------------------+-------+-----+\n"
printf "| %-50s | sync | share %-22s | posix | acl |\n" "soure/destination folder" "(name)"
printf "+----------------------------------------------------+------+------------------------------+-------+-----+\n"

for (( n=0; n<`cat ${CONFIG} | ./libs/jq '.shares | length'`; n++ ))
do
	folder=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].folder"`
	name=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].name"`
	if [[ -z $name ]] ; then
		name=$folder
	fi
	
	to_sync=" "
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].sync"` ; then
		to_sync="X"
	fi
	to_posix=" "
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].posix"` ; then
		to_posix="X"
	fi
	to_acl=" "
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].acl"` ; then
		to_acl="X"
	fi
	to_share=" "
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].share"` ; then
		to_share="X"
	fi
	
	printf "| %-50s |  %1s   |  %s %-25s |   %1s   |  %1s  |\n" "$folder" "$to_sync" "$to_share" "($name)" "$to_posix" "$to_acl"
done

printf "+----------------------------------------------------+------+------------------------------+-------+-----+\n"
echo ""

read -r -p "is that correct (if yes I'm going to start the workflow)? [Y/n]" response
response=`echo $response | tr '[:upper:]' '[:lower:]'`
[[ $response =~ ^(yes|y| ) ]] || exit 0
echo ""

# loop over all shares
for ((n=0;n<`cat ${CONFIG} | ./libs/jq '.shares | length'`;n++))
do
	folder=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].folder"`
	name=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].name"`
	if [[ -z $name ]] ; then
		name=$folder
	fi
	acls=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].acls"`
	
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].sync"` ; then
		synchronize "$folder"
	fi
	
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].posix"` ; then
		propagate_posix "$destination_uri" "$folder" "$destination_user" "$destination_group" "$destination_modus_chmod"
	fi
	
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].acl"` ; then
		propagate_acl "$destination_uri" "$folder" "$acls"
	fi
	
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].share"` ; then
		share "$destination_uri" "$folder" "$name"
	fi
	
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].sync"` || `cat ${CONFIG} | ./libs/jq -r ".shares[$n].posix"` || `cat ${CONFIG} | ./libs/jq -r ".shares[$n].acl"` || `cat ${CONFIG} | ./libs/jq -r ".shares[$n].share"` ; then
		echo ""
	fi
	
done

