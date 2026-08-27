"""
generate_cert.py

One-time (or occasional re-run) self-signed certificate generator for
report_api_server.py's HTTPS listener. LAN-only self-signed TLS - see
report_api_server.py's own SECURITY note for why that's the appropriate
level here rather than a publicly-trusted cert.

Usage:
    pip install cryptography
    python generate_cert.py --host reportserver.local --host 192.168.1.50

Writes report_api_certs/cert.pem and report_api_certs/key.pem next to
this script. cert.pem is also the file SecureZMRP's report_client_config.py
needs a COPY of (as CA_CERT_PATH) - requests/urllib3 will trust this exact
self-signed certificate directly, no separate CA needed for a single-server
setup like this one.

Re-run this (and redistribute the new cert.pem to every ZMRP client) if:
  - the cert expires (10-year validity by default - see --days below)
  - this server's hostname/IP changes (the SAN list below has to match
    whatever host/IP the client's API_BASE_URL uses to reach it)
"""

from __future__ import annotations

import argparse
import datetime
import ipaddress
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

HERE = Path(__file__).parent
OUT_DIR = HERE / "report_api_certs"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--host", action="append", required=True, dest="hosts",
        help="Hostname or IP ZMRP clients will use to reach this server "
             "(repeatable - pass both a hostname and an IP if different "
             "clients might use either one).",
    )
    parser.add_argument(
        "--days", type=int, default=3650,
        help="Validity period in days (default: 10 years - this is a "
             "LAN-internal cert, not subject to the ~398-day limits "
             "public CAs enforce).",
    )
    args = parser.parse_args()

    OUT_DIR.mkdir(exist_ok=True)

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, args.hosts[0]),
    ])

    san_entries = []
    for h in args.hosts:
        try:
            san_entries.append(x509.IPAddress(ipaddress.ip_address(h)))
        except ValueError:
            san_entries.append(x509.DNSName(h))

    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - datetime.timedelta(days=1))
        .not_valid_after(now + datetime.timedelta(days=args.days))
        .add_extension(x509.SubjectAlternativeName(san_entries), critical=False)
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
        .add_extension(
            x509.ExtendedKeyUsage([x509.oid.ExtendedKeyUsageOID.SERVER_AUTH]),
            critical=False,
        )
        .sign(key, hashes.SHA256())
    )

    key_path = OUT_DIR / "key.pem"
    cert_path = OUT_DIR / "cert.pem"

    key_path.write_bytes(
        key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )
    )
    cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))

    print(f"Wrote {cert_path}")
    print(f"Wrote {key_path}")
    print()
    print(f"Copy {cert_path.name} to every SecureZMRP client machine and set")
    print(f"CA_CERT_PATH in report_client_config.py to point at that copy.")
    print(f"NEVER copy {key_path.name} anywhere - it stays only on this server.")


if __name__ == "__main__":
    main()
