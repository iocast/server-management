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



# Sharing
#################################################
#
#sudo visudo
#<user>	ALL= NOPASSWD: /usr/sbin/sharing


function share() {
	[ -z "$1" ] && echo "-param uri (#1) not set"
	[ -z "$2" ] && echo "-param folder (#2) not set"
	[ -z "$3" ] && echo "-param share (#3) not set"

	echo "trying to create share $3 on $2"
	
	sudo sharing -r "$3"
	sudo sharing -r "$2"
	sudo sharing -a "$1$2"
	sudo sharing -e "$2" -n "$3" -s 101 -g 000
}



# Permisson
#################################################

function propagate_posix() {
	[ -z "$1" ] && echo "-param uri (#1) not set"
	[ -z "$2" ] && echo "-param folder (#2) not set"
	[ -z "$3" ] && echo "-param user (#3) not set"
	[ -z "$4" ] && echo "-param group (#4) not set"
	[ -z "$5" ] && echo "-param modus (#5) not set"

	echo "trying to change owner on $1$2 to $3:$4 with permission $5"
	
	chown -R "$3:$4" "$1$2"
	chmod -R "$5" "$1$2"
}


function propagate_acl() {
	[ -z "$1" ] && echo "-param uri (#1) not set"
	[ -z "$2" ] && echo "-param folder (#2) not set"
	[ -z "$3" ] && echo "-param acl array (#3) not set"
	
	echo "propagating defined ACLs to $1$2"
	
	chmod -R -N "$1$2"
	
	for ((g=0;g<`echo "$3" | ./libs/jq '. | length'`;g++))
	do
		local owner=`echo "$3" | ./libs/jq -r ".[$g].owner"`
		local access=`echo "$3" | ./libs/jq -r ".[$g].access"`
		local permission=`echo "$3" | ./libs/jq -r ".[$g].permission"`
		
		chmod +a "$owner $access $permission" "$1$2"
		echo "$owner $access $permission"
		ls -1 "$1$2" | while read element; do
			chmod -R +ai "$owner $access $permission" "$1$2/$element"
		done
		
	done
	
	#launchctl unload /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist
	#launchctl load /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist
	#killall -HUP mDNSResponder
}



# Active Directory
#################################################

function ad_group_members() {
	[ -z "$1" ] && echo "-param user (#1) not set"
	[ -z "$2" ] && echo "-param password (#2) not set"
	[ -z "$3" ] && echo "-param datasource (#3) not set"
	[ -z "$4" ] && echo "-param group (#4) not set"
	
	IFS=' ', read -a arr <<< $( echo `dscl -u ${1} -P ${2} "${3}" -read /Groups/${4} GroupMembership` | sed 's/\\/\\\\/g')
	
	# output a array as astring in the "declare" representation
	declare -p arr | sed -e 's/^declare -a [^=]*=//' 
}
