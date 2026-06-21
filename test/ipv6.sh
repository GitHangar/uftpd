#!/bin/sh
# IPv6 test: FTP control and data channel (EPSV and EPRT) plus TFTP, all
# over ::1.  Skips if the build has no IPv6 support (--disable-ipv6) or
# the host has no IPv6 loopback.

if [ x"${srcdir}" = x ]; then
    srcdir=.
fi
. ${srcdir}/lib.sh

check_dep python3

print "FTP (EPSV + EPRT) and TFTP transfers over ::1 ..."

python3 - <<'EOF'
import ftplib, io, socket, struct, sys

def ftp_xfer(passive):
    ftp = ftplib.FTP()
    ftp.connect("::1", 21, timeout=5)
    ftp.login("anonymous", "a@b")
    ftp.set_pasv(passive)             # True -> EPSV, False -> EPRT
    names = []
    ftp.retrlines("LIST", names.append)
    buf = io.BytesIO()
    ftp.retrbinary("RETR testfile.txt", buf.write)
    ftp.quit()
    return len(names) > 0 and len(buf.getvalue()) > 0

def tftp_get(name):
    s = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    s.settimeout(5)
    s.sendto(b"\x00\x01" + name.encode() + b"\x00octet\x00", ("::1", 69))
    pkt, peer = s.recvfrom(2048)
    op, blk = struct.unpack(">HH", pkt[:4])
    s.sendto(struct.pack(">HH", 4, blk), peer)
    return op == 3 and len(pkt[4:]) > 0

try:
    socket.create_connection(("::1", 21), timeout=5).close()
except OSError as e:
    print("no IPv6 connectivity or listener:", e)
    sys.exit(77)

epsv = ftp_xfer(True)
eprt = ftp_xfer(False)
tftp = tftp_get("testfile.txt")
print("EPSV:", epsv, "| EPRT:", eprt, "| TFTP:", tftp)

sys.exit(0 if (epsv and eprt and tftp) else 1)
EOF
rc=$?

[ $rc -eq 77 ] && SKIP "IPv6 not available"
[ $rc -eq 0 ] && OK
FAIL
