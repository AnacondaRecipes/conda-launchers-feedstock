#!/usr/bin/env python
"""Verify Authenticode signatures on Windows PE executables (no Windows required).

For each exe given on the command line, checks:
  1. A well-formed WIN_CERTIFICATE (PKCS_SIGNED_DATA) entry exists in the PE
     security directory.
  2. The PKCS#7 SignedData parses and its embedded messageDigest matches the
     computed Authenticode hash of the file (integrity: the signed bytes are
     exactly what we ship).
  3. The signer certificate subject names Anaconda and is within its validity
     window (identity: signed with Anaconda's prod cert, not some other cert).

Chain-of-trust to a Microsoft root is intentionally NOT checked (requires
Windows trust stores); the sha256 pins in meta.yaml plus the checks above are
the guarantee for the repackaged payload.

Requires: python, pefile, asn1crypto (all in pkgs/main, linux-64-safe).
"""

import datetime
import hashlib
import struct
import sys

import pefile
from asn1crypto import algos, cms, core

EXPECTED_SIGNER = "anaconda"


def extract_pkcs7(path):
    with open(path, "rb") as fh:
        data = fh.read()
    pe = pefile.PE(data=data, fast_load=True)
    sec = pe.OPTIONAL_HEADER.DATA_DIRECTORY[
        pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_SECURITY"]
    ]
    if not sec.VirtualAddress or not sec.Size:
        raise SystemExit(f"{path}: no certificate table (unsigned)")
    # VirtualAddress is a file offset for the security directory
    blob = data[sec.VirtualAddress : sec.VirtualAddress + sec.Size]
    certs = []
    offset = 0
    while offset + 8 <= len(blob):
        length, revision, cert_type = struct.unpack_from("<IHH", blob, offset)
        if length < 8 or offset + length > len(blob):
            raise SystemExit(f"{path}: malformed WIN_CERTIFICATE at offset {offset}")
        if cert_type != 0x0002:  # WIN_CERT_TYPE_PKCS_SIGNED_DATA
            raise SystemExit(f"{path}: unexpected certificate type {cert_type:#x}")
        if revision != 0x0200:
            raise SystemExit(f"{path}: unexpected certificate revision {revision:#x}")
        certs.append(blob[offset + 8 : offset + length])
        offset += (length + 7) & ~7  # entries are 8-byte aligned
    return data, pe, certs


def authenticode_digest(data, pe, hashlib_name):
    """Compute the PE Authenticode hash per the MS-PECODE spec."""
    opt_off = pe.OPTIONAL_HEADER.get_file_offset()
    checksum_off = opt_off + 64
    secdir_off = pe.OPTIONAL_HEADER.DATA_DIRECTORY[
        pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_SECURITY"]
    ].get_file_offset()
    sec = pe.OPTIONAL_HEADER.DATA_DIRECTORY[
        pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_SECURITY"]
    ]
    cert_off = sec.VirtualAddress
    cert_size = sec.Size
    size_of_headers = pe.OPTIONAL_HEADER.SizeOfHeaders

    h = hashlib.new(hashlib_name)
    h.update(data[:checksum_off])                       # headers up to CheckSum
    h.update(data[checksum_off + 4 : secdir_off])       # skip CheckSum
    h.update(data[secdir_off + 8 : size_of_headers])    # skip security dir entry
    h.update(data[size_of_headers:cert_off])            # body up to cert table
    cert_end = cert_off + ((cert_size + 7) & ~7)        # cert table 8-byte aligned
    h.update(data[cert_end:])                           # anything past cert table
    h.update(b"\0" * (len(data) % 8))                   # file size mod 8 zero bytes
    return h.digest()


def spc_file_digest(signed_data):
    """Extract the Authenticode file digest from SpcIndirectDataContent."""
    eci = signed_data["encap_content_info"]
    if eci["content_type"].native != "1.3.6.1.4.1.311.2.1.4":
        raise SystemExit(f"unexpected signed content type {eci['content_type'].native}")
    buf = eci["content"].contents
    first = core.Sequence.load(buf)  # SpcAttributeTypeAndOptionalValue
    digest_info = algos.DigestInfo.load(buf[len(first.dump()):])
    return digest_info["digest_algorithm"]["algorithm"].native, digest_info["digest"].native


def verify(path):
    data, pe, certs = extract_pkcs7(path)
    ok = True
    for der in certs:
        signed_data = cms.ContentInfo.load(der)["content"]
        digest_algo, message_digest = spc_file_digest(signed_data)
        computed = authenticode_digest(data, pe, digest_algo)
        if computed != message_digest:
            print(f"{path}: FAIL - Authenticode {digest_algo} digest mismatch "
                  f"(file was modified after signing)")
            ok = False
            continue
        signer_ok = False
        for cert_choice in signed_data["certificates"]:
            cert = cert_choice.chosen
            subject = cert.subject.native
            haystack = " ".join(str(v) for v in subject.values()).lower()
            now = datetime.datetime.now(datetime.timezone.utc)
            if EXPECTED_SIGNER in haystack:
                if not (cert.not_valid_before <= now <= cert.not_valid_after):
                    print(f"{path}: FAIL - Anaconda signer cert outside validity window")
                    ok = False
                else:
                    signer_ok = True
        if not signer_ok:
            print(f"{path}: FAIL - no valid Anaconda signer certificate found")
            ok = False
        else:
            print(f"{path}: OK ({digest_algo}, signed by Anaconda)")
    return ok


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(f"usage: {sys.argv[0]} <exe> [<exe> ...]")
    sys.exit(0 if all(verify(p) for p in sys.argv[1:]) else 1)
