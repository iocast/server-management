#!/bin/ksh

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
CONDITIONS

VERSION=0.1
AUTHOR="iocast"
MAIL="iocast@me.com"
USAGE="sudo $0 -c folders.json"


usage() {
cat <<- EOF
usage: $0 [OPTIONS]

OPTIONS:
-c | --config          CONFIG             configuration file
-h | --help                               help text
     --version                            prints the version information

EXAMPLE:
$USAGE
EOF
}


version() {
cat <<- EOF
version $VERSION by $AUTHOR licences under MIT
EOF
}

ADDITIONS=
CONFIG=

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

FOLDERS=
source="`cat ${CONFIG} | ./libs/jq -r '.source'`"


path() {
	[ -z "$1" ] && echo "-param depth (#1) not set"
	[ -z "$2" ] && echo "-param source (#2) not set"
	
	ls -1 "$2" | sed -e 's/ /\\\ /g' | while read ele; do
		if [ $1 -gt 0 ] ; then
			path $(($1-1)) "$2/$ele"
		fi
		FOLDERS[${#FOLDERS[@]}]="${2}/${ele}"
	done
}

for (( n=0; n<`cat ${CONFIG} | ./libs/jq '.folders | length'`; n++ ))
do
	folder=`cat ${CONFIG} | ./libs/jq -r ".folders[$n].folder"`
	depth=`cat ${CONFIG} | ./libs/jq -r ".folders[$n].depth"`
	
	if [ $depth -eq 0 ] ; then
		FOLDERS[${#FOLDERS[@]}]="${source}/${folder}"
	else
		path $(($depth-1)) "$source/$folder"
	fi

done

IFS=""
printf "\nSIZE OF %-57s\n" "'BASE'"
printf "+-----------------------------------------------------------------+\n"
du -csh ${FOLDERS[@]}


for (( n=0; n<`cat ${CONFIG} | ./libs/jq '.subfolders | length'`; n++ ))
do
	parent=`cat ${CONFIG} | ./libs/jq -r ".subfolders[$n].parent"`
	subfolders=`cat ${CONFIG} | ./libs/jq -r ".subfolders[$n].folders"`
	
	unset FOLDERS
	
	for (( s=0; s<`echo "$subfolders" | ./libs/jq '. | length'`; s++ ))
	do
		folder=`echo "$subfolders" | ./libs/jq -r ".[$s].folder"`
		depth=`echo "$subfolders" | ./libs/jq -r ".[$s].depth"`
	
		if [ $depth -eq 0 ] ; then
			FOLDERS[${#FOLDERS[@]}]="${source}/${parent}/${folder}"
		else
			path $(($depth-1)) "$source/${parent}/$folder"
		fi
	done
	
	IFS=""
	printf "\nSIZE OF FOLDER %-50s\n" "'$parent'"
	printf "+-----------------------------------------------------------------+\n"
	du -csh ${FOLDERS[@]}
	
done
