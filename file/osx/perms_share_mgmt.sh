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
CONDITIONS


# IMPORTS
. ./libs/functions.sh


VERSION=0.2
AUTHOR="iocast"
MAIL="iocast@me.com"
USAGE="sudo $0 -c shares.json"


ADDITIONS=
CONFIG=


function usage() {
cat <<- EOF
usage: $0 [OPTIONS]

OPTIONS:
-c | --config           CONFIG            path to the json config file
-h | --help                               show this message
     --version                            prints the version information

EXAMPLE:
$USAGE
EOF
}

function version() {
cat <<- EOF
version $VERSION by $AUTHOR licences under MIT
EOF
}



uri=
user=
group=
modus=

i=0
while (($#)); do
	OPT=$1
	shift
	case $OPT in
		--*)
		case ${OPT:2} in
			config) CONFIG="$1"; shift;;
			version) version; exit 1;;
			help) usage; exit 1;;
		esac;;
		-*)
		case ${OPT:1} in
			c) CONFIG="$1"; shift;;
			h) usage; exit 1;;
		esac;;
		*)
		ADDITIONS[i]="$OPT"
		let i+=1
	esac
done



# check if mandatory variables are set
if [[ -z $CONFIG ]] ; then
	echo "please use a OPTION as follow:"
	echo ""
	usage
	exit 1
fi


uri="`cat ${CONFIG} | ./libs/jq -r '.destination.uri'`"
user="`cat ${CONFIG} | ./libs/jq -r '.destination.user'`"
group="`cat ${CONFIG} | ./libs/jq -r '.destination.group'`"
modus="`cat ${CONFIG} | ./libs/jq -r '.destination.modus.chmod'`"


for (( n=0; n<`cat ${CONFIG} | ./libs/jq '.shares | length'`; n++ ))
do
	folder=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].folder"`
	name=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].name"`
	acls=`cat ${CONFIG} | ./libs/jq -r ".shares[$n].acls"`
	
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].posix"` ; then
		propagate_posix "$uri" "$folder" "$user" "$group" "$modus"
	fi
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].acl"` ; then
		propagate_acl "$uri" "$folder" "$acls"
	fi
	if `cat ${CONFIG} | ./libs/jq -r ".shares[$n].share"` ; then
		share "$uri" "$folder" "$name"
	fi

done

