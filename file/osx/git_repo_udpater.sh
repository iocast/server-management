#!/usr/bin/env bash

#  git_repo_updater.sh
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
Setup / Info:
-------------
1. most of the online git services supports rsa authentification method. Hence, create first a key using key-gen and add the public key to your user account.
2. create a new repo folder and clone the git repos over ssh
3. add your passphrase to the ssh agent (ssh-agent bash and then ssh-add)
4. lastly add a new cron job to /etc/crontab

# m h dom mon dow user  command
0  *    * * *   root    /opt/repos/repo_updater.sh

Dependencies:
-------------
- git-core
CONDITIONS


cd /opt/repos

ls -1p "." | grep / | sed -e 's/ /\\\ /g' | while read ele; do
	cd ${ele}
	echo "update repo ${ele}"
	git pull
	cd ..
done
