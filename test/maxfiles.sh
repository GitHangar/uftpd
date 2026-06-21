#!/bin/sh
#set -x

# Verify uftpd does not leak file descriptors across sessions.  The leak
# we guard against is one descriptor per connection, so it is exposed by
# making more connections than the descriptor limit -- the absolute
# number does not matter.  Use a low limit, set *before* lib.sh starts
# uftpd so the daemon inherits it, to keep the test fast.
ulimit -n 128

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

# A bit more than the limit, so a per-connection leak runs us out.
max=$(( $(ulimit -n) + 20 ))

get()
{
	ftp -n 127.0.0.1 <<-EOF
		user anonymous a@b
		get testfile.txt
		bye
		EOF
}

check_dep ftp

i=1
while [ $i -lt $max ]; do
    get
    rm -f testfile.txt
    i=$((i + 1))
done
