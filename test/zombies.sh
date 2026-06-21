#!/bin/sh
# Regression test for issue #32: a session that fails during setup must
# exit the forked child, not fall back into the parent's accept loop.
# Otherwise the failed child becomes a rogue listener that accepts and
# forks ever more sessions, leaving defunct (zombie) processes behind
# until the system runs out of PIDs.
#
# We trigger the failure deterministically: serve a directory, remove it
# so chroot() fails in every forked child, fire a few connections, and
# verify the number of uftpd processes does not grow.

# Capture the build dir before lib.sh's setup() changes directory.
bindir=$(pwd)/../src

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

check_dep python3
check_dep pgrep

srv="$DIR/served"
mkdir -p "$srv"

# Run daemonized (no -n) so uftpd is in its own session; its SIGTERM
# handler does killpg(), which would otherwise tear down the test harness.
"$bindir/uftpd" "$srv" -o ftp=2398,tftp=0 -l err -p "$DIR/zpid" >"$DIR/zlog" 2>&1
sleep 1
echo "$(cat "$DIR/zpid" 2>/dev/null)" >> "$DIR/PIDs"

# Remove the served directory: chroot() now fails for every new session.
rmdir "$srv"

base=$(pgrep -c uftpd || echo 0)
dprint "uftpd processes before: $base"

print "Firing connections that fail in the forked child ..."
i=0
while [ $i -lt 5 ]; do
    python3 -c 'import socket
try:
    s = socket.create_connection(("127.0.0.1", 2398), timeout=2)
    s.recv(64); s.close()
except Exception:
    pass' 2>/dev/null || true
    i=$((i + 1))
done
sleep 1

after=$(pgrep -c uftpd || echo 0)
dprint "uftpd processes after:  $after"

# With the fix only the single parent listener remains (per instance);
# without it the count explodes as rogue listeners fork more sessions.
[ "$after" -le "$((base + 1))" ] || FAIL "uftpd processes grew $base -> $after, rogue listeners?"

OK
