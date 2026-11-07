#!/usr/bin/env python3
"""Vectores de prueba de F10 (docs/PLAN_F10.md) hechos con la biblioteca `cryptography` siguiendo
ios/MProgress/Domain/E2EE.swift paso a paso. Las pruebas de Android (E2EEVectorsTest.kt) usan la salida.

Correr: python3 f10_vectors.py > ../resources/f10_vectors.json
"""
import base64
import hashlib
import json

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import serialization

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode()


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def hkdf(ikm: bytes, salt: bytes, info: bytes) -> bytes:
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=salt, info=info).derive(ikm)


def seal(plain: bytes, key: bytes, ad: bytes, nonce: bytes) -> bytes:
    # CryptoKit AES.GCM combined: nonce (12) | cifrado | etiqueta (16). AESGCM.encrypt devuelve cifrado | etiqueta.
    return nonce + AESGCM(key).encrypt(nonce, plain, ad)


def pub(priv: bytes) -> bytes:
    return X25519PrivateKey.from_private_bytes(priv).public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def shared(priv: bytes, peer: bytes) -> bytes:
    from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PublicKey
    return X25519PrivateKey.from_private_bytes(priv).exchange(X25519PublicKey.from_public_bytes(peer))


def encode32(data: bytes) -> str:
    out, buf, bits = "", 0, 0
    for byte in data:
        buf = ((buf << 8) | byte) & 0xFFFFFFFF
        bits += 8
        while bits >= 5:
            bits -= 5
            out += ALPHABET[(buf >> bits) & 31]
    if bits > 0:
        out += ALPHABET[(buf << (5 - bits)) & 31]
    return out


def fmt(code: str) -> str:
    return "-".join(code[i:i + 4] for i in range(0, len(code), 4))


def seq(start: int, count: int) -> bytes:
    return bytes((start + i) & 0xFF for i in range(count))


space = "5a0f3c1e-8d2b-4c6a-9e7f-112233445566"
sender_device = "0d000000-0000-4000-8000-00000000000a"
recipient_device = "0d000000-0000-4000-8000-00000000000b"
sender_priv = seq(0x01, 32)
recipient_priv = seq(0x41, 32)
space_key = seq(0x80, 32)
wrap_nonce = seq(0xA0, 12)

wrapping_key = hkdf(shared(sender_priv, pub(recipient_priv)), space.encode(), b"mprogress-space-key")
wrapped = b64(bytes([1]) + pub(sender_priv) + seal(space_key, wrapping_key, f"{space}|{recipient_device}".encode(), wrap_nonce))

recovery_bytes = seq(0x10, 15)
code = fmt(encode32(recovery_bytes))
recovery_key = hkdf(code.replace("-", "").encode(), b"mprogress-recovery", b"mprogress-recovery-key")
recovery_nonce = seq(0xB0, 12)
recovery_wrapped = b64(bytes([2]) + seal(space_key, recovery_key, f"{space}|recuperacion".encode(), recovery_nonce))

entry_id = "e1000000-0000-4000-8000-000000000001"
payload = json.dumps({"id": entry_id.upper(), "name": "Éxito", "amountMinor": 8430000}, ensure_ascii=False, separators=(",", ":")).encode()
envelope_nonce = seq(0xC0, 12)
envelope = b64(seal(payload, space_key, f"{space}|entries|{entry_id}".encode(), envelope_nonce))

verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
challenge = b64url(hashlib.sha256(verifier.encode()).digest())
assert challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

print(json.dumps({
    "space_id": space,
    "sender_device_id": sender_device,
    "recipient_device_id": recipient_device,
    "sender_private": b64(sender_priv),
    "sender_public": b64(pub(sender_priv)),
    "recipient_private": b64(recipient_priv),
    "recipient_public": b64(pub(recipient_priv)),
    "shared_secret": b64(shared(sender_priv, pub(recipient_priv))),
    "wrapping_key": b64(wrapping_key),
    "space_key": b64(space_key),
    "wrap_nonce": b64(wrap_nonce),
    "wrapped_key": wrapped,
    "recovery_bytes": b64(recovery_bytes),
    "recovery_code": code,
    "recovery_key": b64(recovery_key),
    "recovery_nonce": b64(recovery_nonce),
    "recovery_wrapped": recovery_wrapped,
    "entry_id": entry_id,
    "payload": payload.decode(),
    "envelope_nonce": b64(envelope_nonce),
    "envelope": envelope,
    "pkce_verifier": verifier,
    "pkce_challenge": challenge,
    "pkce_random48": b64(seq(0x00, 48)),
    "pkce_verifier48": b64url(seq(0x00, 48)),
}, indent=2, ensure_ascii=False))
