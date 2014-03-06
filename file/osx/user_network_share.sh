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


VERSION=0.1
AUTHOR="iocast"
MAIL="iocast@me.com"
USAGE="sudo $0"


CONFIG=


function usage() {
cat <<- EOF
usage: $0 [OPTIONS]

OPTIONS:
-h | --help                               prints this help
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
			usage; exit 1;;
	esac
done


DEFAULT_DATASOURCE="/Active Directory/D/All Domains"
DEFAULT_ADMIN="root"
DEFAULT_GROUP="root"
DEFAULT_MODUS="0700"


# if config file is not set, ask for input
if [[ -z $CONFIG ]] ; then
	read -p "Active Directory username: " username
	read -s -p "Enter Password for AD user $username: " password
	echo ""

	read -p "Please enter the datasource (default: [$DEFAULT_DATASOURCE]): " datasource
	datasource="${datasource:-$DEFAULT_DATASOURCE}"

	read -p "Please enter the ad group: " ad_group
	[ -z "$ad_group" ] && exit 0

	read -p "Has the group $ad_group read access (default: n) [Y/n]: " group_access
	group_access=`echo $group_access | tr '[:upper:]' '[:lower:]'`
	if [[ $group_access =~ (yes|y| ) ]] ; then
		group_access=true
	else
		group_access=false
	fi

	read -p "Please enter the home directory: " home
	[ -z "$home" ] && exit 0

	read -p "Please enter the archive directory (optional): " archive_path

	read -p "Please enter the posix owner (default: [$DEFAULT_ADMIN]): " admin
	admin="${admin:-$DEFAULT_ADMIN}"

	read -p "Please enter the posix group (default: [$DEFAULT_GROUP]): " group
	group="${group:-$DEFAULT_GROUP}"

	read -p "Please enter the posix modus (default: [$DEFAULT_MODUS]): " modus
	modus="${modus:-$DEFAULT_MODUS}"
	
	
	read -p "Should I propagate posix on existing user folders (default: n) [Y/n]: " posix
	posix=`echo $posix | tr '[:upper:]' '[:lower:]'`
	if [[ $posix =~ (yes|y| ) ]] ; then
		posix=true
	else
		posix=false
	fi

	read -p "Should I propagate acl on existing user folders (default: n) [Y/n]: " acl
	acl=`echo $acl | tr '[:upper:]' '[:lower:]'`
	if [[ $acl =~ (yes|y| ) ]] ; then
		acl=true
	else
		acl=false
	fi

	
else
	username="`cat ${CONFIG} | ./libs/jq -r '.datasource.credentials.username'`"
	password="`cat ${CONFIG} | ./libs/jq -r '.datasource.credentials.password'`"
	
	datasource="`cat ${CONFIG} | ./libs/jq -r '.datasource.path'`"
	ad_group="`cat ${CONFIG} | ./libs/jq -r '.datasource.group'`"
	home="`cat ${CONFIG} | ./libs/jq -r '.datasource.home'`"
	archive_path="`cat ${CONFIG} | ./libs/jq -r '.datasource.archive'`"
	
	admin="`cat ${CONFIG} | ./libs/jq -r '.posix.username'`"
	group="`cat ${CONFIG} | ./libs/jq -r '.posix.group'`"
	modus="`cat ${CONFIG} | ./libs/jq -r '.posix.modus'`"
	
	posix="`cat ${CONFIG} | ./libs/jq -r '.propagation.posix'`"
	acl="`cat ${CONFIG} | ./libs/jq -r '.propagation.acl'`"
	
fi

eval "declare -a g_members=$( ad_group_members "${username}" "${password}" "${datasource}" "${ad_group}" )"

archives=()

members=()
for member in "${g_members[@]}"; do
	if [[ ${member} == D\\* ]] ; then
		members+=("${member}")
	fi
done

folders=( $( ls -1p "${home}" | grep /  ) )
for folder in "${folders[@]}"; do
	ondisk=false
	for index in "${!members[@]}"; do
		if [[ ${members[$index]#D\\} == ${folder%?} ]] ; then
			unset members[$index]
			ondisk=true
			break
		fi
	done
	if ! $ondisk; then
		archives+=("${folder}")
	fi
done

echo "archiving folders"
if [[ ! -z $archive_path ]] ; then
	for archive in "${archives[@]}"; do
		echo "archiving ${archive%/} to ${archive_path}"
		mv ${home}${archive%/} ${archive_path}
	done
fi

echo "creating folders"
for member in "${members[@]}"; do
	echo "create user folder ${member#D\\}"
	
	user="${member#D\\}"
	mkdir "${home}${user}"
	propagate_posix "${home}" "${user}" "$admin" "$group" "$modus"
	acls='[{"owner": "user:D\\'
	acls+="${user}"
	acls+='", "access": "allow", "permission": "readattr,writeattr,readextattr,writeextattr,readsecurity,writesecurity,list,search,add_file,add_subdirectory,delete_child,read,write,append,execute,file_inherit,directory_inherit,chown"}'
	
	if $group_access ; then
		acls+=',{"owner": "group:D\\'
		acls+="${ad_group}"
		acls+='", "access": "allow", "permission": "readattr,readextattr,readsecurity,list,search,read,file_inherit,directory_inherit"}'
	fi
	
	acls+=']'
	
	propagate_acl "${home}" "${user}" "$acls"
done

echo "propagate posix and acl"
for folder in "${folders[@]}"; do
	user="${folder%/}"
	if $posix ; then
		propagate_posix "${home}" "${user}" "$admin" "$group" "$modus"
	fi
	
	if $acl ; then
		acls='[{"owner": "user:D\\'
		acls+="${user}"
		acls+='", "access": "allow", "permission": "readattr,writeattr,readextattr,writeextattr,readsecurity,writesecurity,list,search,add_file,add_subdirectory,delete_child,read,write,append,execute,file_inherit,directory_inherit,chown"}'
	
		if $group_access ; then
			acls+=',{"owner": "group:D\\'
			acls+="${ad_group}"
			acls+='", "access": "allow", "permission": "readattr,readextattr,readsecurity,list,search,read,file_inherit,directory_inherit"}'
		fi
	
		acls+=']'
		
		propagate_acl "${home}" "${user}" "$acls"
	fi
done

