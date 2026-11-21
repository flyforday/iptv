#!/usr/bin/env python3
"""Recrée la clé de signature Android de Lemaire TV à partir d'une phrase secrète.

La même phrase donne toujours exactement la même clé et le même certificat :
il suffit donc de garder la phrase dans un secret GitHub (ANDROID_SIGNING_SEED),
sans jamais stocker le fichier de clé nulle part. Android accepte alors chaque
nouvelle version comme une mise à jour de la précédente.

Usage : ANDROID_SIGNING_SEED=... python3 tool/make_keystore.py sortie.p12
Le mot de passe du fichier produit est la phrase elle-même.
"""

import datetime
import hashlib
import hmac
import os
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

ALIAS = b"famille"
SALT = b"lemaire-tv-android-signing-v1"


class Drbg:
    """Générateur déterministe (HMAC-SHA256, façon HMAC_DRBG)."""

    def __init__(self, seed: bytes):
        self.k = b"\x00" * 32
        self.v = b"\x01" * 32
        self._update(seed)

    def _update(self, data: bytes = b"") -> None:
        self.k = hmac.new(self.k, self.v + b"\x00" + data, hashlib.sha256).digest()
        self.v = hmac.new(self.k, self.v, hashlib.sha256).digest()
        if data:
            self.k = hmac.new(self.k, self.v + b"\x01" + data, hashlib.sha256).digest()
            self.v = hmac.new(self.k, self.v, hashlib.sha256).digest()

    def bytes(self, n: int) -> bytes:
        out = b""
        while len(out) < n:
            self.v = hmac.new(self.k, self.v, hashlib.sha256).digest()
            out += self.v
        self._update()
        return out[:n]

    def int_bits(self, bits: int) -> int:
        return int.from_bytes(self.bytes(bits // 8), "big")


def is_probable_prime(n: int, rng: Drbg, rounds: int = 64) -> bool:
    if n < 2:
        return False
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            return n == p
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for _ in range(rounds):
        a = 2 + rng.int_bits(256) % (n - 3)
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    return True


def make_prime(rng: Drbg, bits: int, e: int) -> int:
    while True:
        c = rng.int_bits(bits) | (1 << (bits - 1)) | (1 << (bits - 2)) | 1
        if c % e != 1 and is_probable_prime(c, rng):
            return c


def private_key(seed: str) -> rsa.RSAPrivateKey:
    material = hashlib.pbkdf2_hmac("sha256", seed.encode(), SALT, 300_000, 64)
    rng = Drbg(material)
    e = 65537
    while True:
        p = make_prime(rng, 1024, e)
        q = make_prime(rng, 1024, e)
        if p == q:
            continue
        if p < q:
            p, q = q, p
        n = p * q
        if n.bit_length() != 2048:
            continue
        phi = (p - 1) * (q - 1)
        d = pow(e, -1, phi)
        numbers = rsa.RSAPrivateNumbers(
            p=p,
            q=q,
            d=d,
            dmp1=d % (p - 1),
            dmq1=d % (q - 1),
            iqmp=pow(q, -1, p),
            public_numbers=rsa.RSAPublicNumbers(e, n),
        )
        return numbers.private_key()


def certificate(key: rsa.RSAPrivateKey) -> x509.Certificate:
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Lemaire TV")])
    return (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(1)
        .not_valid_before(datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc))
        .not_valid_after(datetime.datetime(2076, 1, 1, tzinfo=datetime.timezone.utc))
        .sign(key, hashes.SHA256())
    )


def main() -> None:
    seed = os.environ.get("ANDROID_SIGNING_SEED", "")
    if len(seed) < 16:
        sys.exit("ANDROID_SIGNING_SEED manquant ou trop court (16 caractères min.)")
    key = private_key(seed)
    cert = certificate(key)
    data = pkcs12.serialize_key_and_certificates(
        ALIAS,
        key,
        cert,
        None,
        serialization.BestAvailableEncryption(seed.encode()),
    )
    with open(sys.argv[1], "wb") as f:
        f.write(data)
    fp = hashlib.sha256(cert.public_bytes(serialization.Encoding.DER)).hexdigest()
    print(f"Certificat SHA-256 : {fp[:16]}…")


if __name__ == "__main__":
    main()
