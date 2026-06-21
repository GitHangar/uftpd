#!/bin/sh
# Regression test for issue #45: TFTP block numbers are 16-bit and wrap
# after 65535.  Using the smallest negotiable block size we download a
# file spanning more than 65535 blocks and verify the whole transfer
# completes correctly across the rollover.
#
# Without the fix the server desyncs at the wrap (the wrapped 16-bit ACK
# no longer matches its wide internal counter) and restarts/loops, so
# the transfer never completes with the right byte count.

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

check_dep python3

# MIN_SEGSIZE is 32; 65541 blocks * 32 = a hair over 2 MiB, enough to
# cross the 16-bit block rollover at 65536.
SIZE=$((65541 * 32 + 5))
head -c "$SIZE" /dev/urandom > "$DIR/big.bin"

print "Downloading $SIZE bytes (>65535 blocks of 32) across the rollover ..."

SIZE=$SIZE python3 - <<'EOF'
import os, socket, struct, sys

OACK, DATA, ERROR, ACK = 6, 3, 5, 4
blksize = 32
expect  = int(os.environ["SIZE"])
srv     = ("127.0.0.1", 69)

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(10)

# RRQ requesting the small block size
rrq = (b"\x00\x01big.bin\x00octet\x00blksize\x00%d\x00" % blksize)
s.sendto(rrq, srv)

pkt, tid = s.recvfrom(2048)
op = struct.unpack(">H", pkt[:2])[0]
if op == OACK:
    s.sendto(struct.pack(">HH", ACK, 0), tid)   # ack options, start xfer
elif op == ERROR:
    print("server ERROR:", pkt[4:].split(b"\0")[0].decode("latin1"))
    sys.exit(1)
else:
    print("unexpected first packet, opcode", op)
    sys.exit(1)

total  = 0
blocks = 0
limit  = expect // blksize + 100      # generous cap to catch a resend loop

while True:
    pkt, _ = s.recvfrom(2048)
    op, blk = struct.unpack(">HH", pkt[:4])
    if op == ERROR:
        print("server ERROR:", pkt[4:].split(b"\0")[0].decode("latin1"))
        sys.exit(1)
    if op != DATA:
        print("expected DATA, got opcode", op)
        sys.exit(1)

    data = pkt[4:]
    total  += len(data)
    blocks += 1
    s.sendto(struct.pack(">HH", ACK, blk), tid)

    if blocks > limit:
        print(f"too many blocks ({blocks}), server stuck in a resend loop?")
        sys.exit(1)
    if len(data) < blksize:
        break

print(f"received {total} bytes in {blocks} blocks, expected {expect}")
sys.exit(0 if total == expect else 1)
EOF

[ $? -eq 0 ] && OK
FAIL
