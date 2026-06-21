#!/bin/sh
# Regression test for issue #43: a TFTP OACK must contain only the
# acknowledged options, with no trailing NUL padding.  A malformed OACK
# (extra zero bytes) is rejected by strict clients such as Cisco
# switches and U-Boot.
#
# We send a raw RRQ requesting a blksize option and verify the OACK the
# server replies with is byte-for-byte what RFC 2347 mandates.

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

check_dep python3

print "Requesting RRQ with blksize option, inspecting OACK ..."

python3 - <<'EOF'
import socket, sys

blksize = b"1432"

# RRQ = opcode(1) filename\0 mode\0 blksize\0 <value>\0
rrq = (b"\x00\x01" + b"testfile.txt\x00" + b"octet\x00"
       + b"blksize\x00" + blksize + b"\x00")

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)
s.sendto(rrq, ("127.0.0.1", 69))

try:
    data, _ = s.recvfrom(2048)
except socket.timeout:
    print("No reply from server")
    sys.exit(1)

# OACK = opcode(6) blksize\0 <value>\0   -- and nothing more
want = b"\x00\x06" + b"blksize\x00" + blksize + b"\x00"

print("OACK got :", data.hex(" "))
print("OACK want:", want.hex(" "))

if int.from_bytes(data[:2], "big") != 6:
    print("Expected OACK (opcode 6)")
    sys.exit(1)

if data != want:
    print(f"Malformed OACK: {len(data)} bytes, expected {len(want)} "
          "(trailing NUL padding?)")
    sys.exit(1)

print("OACK is well-formed, no trailing padding")
sys.exit(0)
EOF

[ $? -eq 0 ] && OK
FAIL
