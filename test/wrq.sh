#!/bin/sh
# Regression test for issue #41: a retransmitted TFTP WRQ must not reopen
# the destination file.  Reopening leaks a file descriptor on every retry
# (eventually "Too many open files") and truncates already-received data.
#
# Upload a multi-block file, inject a duplicate WRQ in the middle of the
# transfer, and verify the upload still completes and the stored file is
# byte-for-byte identical to the source.

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

check_dep python3

# Three full 512-byte blocks plus a short final block.
head -c 1586 /dev/urandom > "$CDIR/src.dat"

print "Uploading with a duplicate WRQ injected mid-transfer ..."

SRC="$CDIR/src.dat" python3 - <<'EOF'
import os, socket, struct, sys

DATA, ACK, ERROR = 3, 4, 5
src = open(os.environ["SRC"], "rb").read()

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)
wrq = b"\x00\x02upload.dat\x00octet\x00"

def data(n, b):
    s.sendto(struct.pack(">HH", DATA, n) + b, tid)

def rx():
    pkt, _ = s.recvfrom(2048)
    return struct.unpack(">HH", pkt[:4]) + (pkt[4:],)

s.sendto(wrq, ("127.0.0.1", 69))
pkt, tid = s.recvfrom(2048)
op, blk = struct.unpack(">HH", pkt[:4])
if (op, blk) != (ACK, 0):
    print("bad start ack", op, blk); sys.exit(1)

data(1, src[0:512]);    op, blk, _ = rx(); assert (op, blk) == (ACK, 1), (op, blk)
data(2, src[512:1024]); op, blk, _ = rx(); assert (op, blk) == (ACK, 2), (op, blk)

# Duplicate WRQ, as a u-boot style client does when our ACK is lost.
s.sendto(wrq, tid)
op, blk, extra = rx()
if op == ERROR:
    print("server errored on duplicate WRQ:", extra.split(b"\0")[0]); sys.exit(1)

# Without the fix the file was reopened (truncated) and the expected
# block reset, so this block is rejected and the transfer never finishes.
data(3, src[1024:1536])
op, blk, extra = rx()
if op == ERROR:
    print("block 3 rejected after duplicate WRQ:", extra.split(b"\0")[0]); sys.exit(1)
assert (op, blk) == (ACK, 3), (op, blk)

data(4, src[1536:1586]); op, blk, _ = rx(); assert (op, blk) == (ACK, 4), (op, blk)
print("upload completed across the duplicate WRQ")
EOF

[ $? -ne 0 ] && FAIL

# Let the session child flush and exit before inspecting the file.
sleep 1
cmp "$CDIR/src.dat" "$DIR/upload.dat" || FAIL "stored file differs from source"

OK
