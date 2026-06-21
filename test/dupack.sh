#!/bin/sh
# Regression test for issue #44: when a DATA packet is lost the client
# re-acknowledges the last block it received.  The server must resend
# the missing block, not ignore the ACK number and stream past it.
#
# We download a multi-block file, then replay an ACK for an earlier
# block (simulating a lost DATA packet) and verify the server resends
# that block rather than advancing to the next one.

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

check_dep python3

# Default TFTP block size is 512 bytes, make a file of several blocks.
head -c 4096 /dev/zero > "$DIR/big.bin"

print "Downloading, replaying a stale ACK to force a resend ..."

python3 - <<'EOF'
import socket, struct, sys

DATA, ACK, ERROR = 3, 4, 5
srv = ("127.0.0.1", 69)

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)

def recv():
    pkt, peer = s.recvfrom(2048)
    op, blk = struct.unpack(">HH", pkt[:4])
    if op == ERROR:
        print("server ERROR:", pkt[4:].split(b"\0")[0].decode("latin1"))
        sys.exit(1)
    if op != DATA:
        print("expected DATA, got opcode", op)
        sys.exit(1)
    return blk, peer

# RRQ, plain octet mode (no options -> server sends DATA block 1 directly)
s.sendto(b"\x00\x01big.bin\x00octet\x00", srv)

blk, tid = recv()                       # DATA 1, learn server TID port
assert blk == 1, f"first block was {blk}"
s.sendto(struct.pack(">HH", ACK, 1), tid)

blk, _ = recv()                         # DATA 2
assert blk == 2, f"second block was {blk}"

# Simulate that DATA 2 was lost: re-ACK block 1.  A correct server
# retransmits block 2; the buggy one skips ahead to block 3.
s.sendto(struct.pack(">HH", ACK, 1), tid)
blk, _ = recv()
print("after stale ACK(1), server sent block", blk)
sys.exit(0 if blk == 2 else 1)
EOF

[ $? -eq 0 ] && OK
FAIL
