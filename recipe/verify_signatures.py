#!/usr/bin/env python
"""Recipe test: verify each launcher's sha256 pin and Anaconda Authenticode
signature (PE cert table present, PKCS#7 file digest matches, Anaconda signer
cert in validity). Chain-of-trust to a Microsoft root is out of scope; the
sha256 pins cover it.

Usage: python verify_signatures.py cli-64.exe=<sha256> [gui-64.exe=<sha256> ...]
Bare filenames resolve under <sys.prefix>/share/conda-launchers, so the same
command works under cmd.exe and POSIX shells (the test env's python IS the
test env). Requires: python, pefile, asn1crypto (all in pkgs/main).
"""

import datetime
import hashlib
import os
import struct
import sys

import pefile
from asn1crypto import algos, cms, core

DIR = os.path.join(sys.prefix, "share", "conda-launchers")
SEC_DIR = pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_SECURITY"]


def fail(name, msg):
    print(f"{name}: FAIL - {msg}")
    return False


def check(arg):
    name, _, expected = arg.partition("=")
    path = os.path.join(DIR, name)
    if not os.path.isfile(path):
        return fail(name, "not found")
    with open(path, "rb") as fh:
        data = fh.read()
    if hashlib.sha256(data).hexdigest() != expected:
        return fail(name, "sha256 mismatch")

    pe = pefile.PE(data=data, fast_load=True)
    sec = pe.OPTIONAL_HEADER.DATA_DIRECTORY[SEC_DIR]
    blob = data[sec.VirtualAddress : sec.VirtualAddress + sec.Size] if sec.VirtualAddress else b""
    if len(blob) < 8:
        return fail(name, "unsigned (no certificate table)")
    length, revision, ctype = struct.unpack_from("<IHH", blob, 0)
    if (revision, ctype) != (0x0200, 0x0002):  # WIN_CERT_REVISION_2, PKCS_SIGNED_DATA
        return fail(name, f"unexpected WIN_CERTIFICATE revision/type {revision:#x}/{ctype:#x}")
    sd = cms.ContentInfo.load(blob[8:length])["content"]

    # The file's Authenticode digest lives in SpcIndirectDataContent (the
    # SignedData content); the signed-attribute messageDigest hashes that
    # structure, not the file.
    buf = sd["encap_content_info"]["content"].contents
    digest_info = algos.DigestInfo.load(buf[len(core.Sequence.load(buf).dump()):])
    algo = digest_info["digest_algorithm"]["algorithm"].native
    embedded = digest_info["digest"].native

    # Authenticode hash per MS-PECODE: everything except the CheckSum field,
    # the security-directory entry, and the (8-byte-aligned) cert table.
    opt = pe.OPTIONAL_HEADER.get_file_offset()
    sec_off = sec.get_file_offset()
    h = hashlib.new(algo)
    h.update(data[: opt + 64])
    h.update(data[opt + 68 : sec_off])
    h.update(data[sec_off + 8 : pe.OPTIONAL_HEADER.SizeOfHeaders])
    h.update(data[pe.OPTIONAL_HEADER.SizeOfHeaders : sec.VirtualAddress])
    h.update(data[sec.VirtualAddress + ((sec.Size + 7) & ~7) :])
    h.update(b"\0" * (len(data) % 8))
    if h.digest() != embedded:
        return fail(name, f"Authenticode {algo} digest mismatch (modified after signing)")

    now = datetime.datetime.now(datetime.timezone.utc)
    for choice in sd["certificates"]:
        cert = choice.chosen
        if "anaconda" in str(cert.subject.native).lower() and cert.not_valid_before <= now <= cert.not_valid_after:
            print(f"{name}: OK ({algo}, signed by Anaconda)")
            return True
    return fail(name, "no valid Anaconda signer certificate")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(f"usage: {sys.argv[0]} <name>=<sha256> ...")
    results = [check(a) for a in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)
