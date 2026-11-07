package com.olarte.mprogress.domain

import com.olarte.mprogress.data.cloud.AndroidCrypto
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * F10: Android produce y lee los mismos bytes que iOS. Los vectores (src/test/resources/f10_vectors.json) salen de
 * src/test/vectors/f10_vectors.py, que sigue ios/MProgress/Domain/E2EE.swift paso a paso con la biblioteca `cryptography`.
 */
class E2EEVectorsTest {
    private val v: Map<String, String> by lazy {
        val text = javaClass.classLoader!!.getResourceAsStream("f10_vectors.json")!!.readBytes().toString(Charsets.UTF_8)
        Regex("\"([a-z0-9_]+)\":\\s*\"((?:[^\"\\\\]|\\\\.)*)\"").findAll(text)
            .associate { it.groupValues[1] to it.groupValues[2].replace("\\\"", "\"").replace("\\\\", "\\") }
    }

    private fun b(name: String) = E2EEFormat.unb64(v.getValue(name))!!

    /** Un cifrador que entrega los bytes "al azar" que se le dan, en orden. */
    private fun fixed(vararg chunks: ByteArray): AndroidCrypto {
        val queue = ArrayDeque(chunks.toList())
        return AndroidCrypto { n -> queue.removeFirst().also { assertEquals(n, it.size) } }
    }

    private val crypto = AndroidCrypto()
    private val sender get() = DeviceKeyPair(b("sender_private"), b("sender_public"))
    private val recipient get() = DeviceKeyPair(b("recipient_private"), b("recipient_public"))

    @Test fun x25519AndHkdfMatchIOS() {
        assertArrayEquals(b("sender_public"), crypto.publicKey(b("sender_private")))
        assertArrayEquals(b("recipient_public"), crypto.publicKey(b("recipient_private")))
        val shared = crypto.sharedSecret(b("sender_private"), b("recipient_public"))
        assertArrayEquals(b("shared_secret"), shared)
        assertArrayEquals(shared, crypto.sharedSecret(b("recipient_private"), b("sender_public")))
        assertArrayEquals(b("wrapping_key"), crypto.hkdf(shared, v.getValue("space_id").toByteArray(), "mprogress-space-key".toByteArray(), 32))
    }

    @Test fun wrapProducesTheSameBytesAsIOS() {
        val wrapped = SpaceKeyWrap.wrap(b("space_key"), v.getValue("space_id"), v.getValue("recipient_device_id"), b("recipient_public"), sender, fixed(b("wrap_nonce")))
        assertEquals(v.getValue("wrapped_key"), wrapped)
        // Los UUID en mayúscula dan lo mismo: el formato los pasa a minúscula.
        val upper = SpaceKeyWrap.wrap(b("space_key"), v.getValue("space_id").uppercase(), v.getValue("recipient_device_id").uppercase(), b("recipient_public"), sender, fixed(b("wrap_nonce")))
        assertEquals(v.getValue("wrapped_key"), upper)
    }

    @Test fun unwrapReadsWhatIOSWrapped() {
        val opened = SpaceKeyWrap.unwrap(v.getValue("wrapped_key"), v.getValue("space_id"), v.getValue("recipient_device_id"), recipient,
            listOf(b("sender_public")), crypto)
        assertArrayEquals(b("space_key"), opened.spaceKey)
        assertArrayEquals(b("sender_public"), opened.senderPublicKey)
    }

    @Test fun unwrapRejectsStrangersAndOtherDevices() {
        try {
            SpaceKeyWrap.unwrap(v.getValue("wrapped_key"), v.getValue("space_id"), v.getValue("recipient_device_id"), recipient, listOf(b("recipient_public")), crypto)
            fail("debió rechazar al que envolvió")
        } catch (e: E2EEError.UntrustedSender) {}
        try {
            SpaceKeyWrap.unwrap(v.getValue("wrapped_key"), v.getValue("space_id"), v.getValue("sender_device_id"), recipient, null, crypto)
            fail("los datos asociados son de otro dispositivo")
        } catch (e: E2EEError.CannotOpen) {}
        try {
            SpaceKeyWrap.unwrap("no es base64", v.getValue("space_id"), v.getValue("recipient_device_id"), recipient, null, crypto)
            fail()
        } catch (e: E2EEError.BadFormat) {}
    }

    @Test fun wrapRoundTripBetweenTwoNewDevices() {
        val a = crypto.newAgreementKeyPair(); val c = crypto.newAgreementKeyPair()
        val key = SpaceKeyWrap.newSpaceKey(crypto)
        val space = "11111111-2222-4333-8444-555555555555"; val device = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
        val wrapped = SpaceKeyWrap.wrap(key, space, device, c.publicKey, a, crypto)
        assertArrayEquals(key, SpaceKeyWrap.unwrap(wrapped, space, device, c, listOf(a.publicKey), crypto).spaceKey)
    }

    @Test fun recoveryCodeMatchesIOS() {
        assertEquals(v.getValue("recovery_code"), RecoveryCode.generate(fixed(b("recovery_bytes"))))
        val code = v.getValue("recovery_code")
        assertTrue(Regex("^([A-HJ-NP-Z2-9]{4}-){5}[A-HJ-NP-Z2-9]{4}$").matches(code))
        val key = RecoveryCode.key(code, crypto)
        assertArrayEquals(b("recovery_key"), key)
        // Minúsculas, espacios y sin guiones: la misma llave.
        assertArrayEquals(key, RecoveryCode.key(" " + code.lowercase().replace("-", " ") + " ", crypto))
        assertNull(RecoveryCode.normalize("ABCD-EFGH-IJKL-0000-1111-2222"))
        assertNull(RecoveryCode.normalize("ABCD"))
        try { RecoveryCode.key("hola", crypto); fail() } catch (e: E2EEError.BadRecoveryCode) {}
    }

    @Test fun recoveryWrapMatchesIOS() {
        val space = v.getValue("space_id")
        assertEquals(v.getValue("recovery_wrapped"), SpaceKeyWrap.wrapForRecovery(b("space_key"), space, b("recovery_key"), fixed(b("recovery_nonce"))))
        assertArrayEquals(b("space_key"), SpaceKeyWrap.unwrapWithRecovery(v.getValue("recovery_wrapped"), space, b("recovery_key"), crypto))
        try {
            SpaceKeyWrap.unwrapWithRecovery(v.getValue("recovery_wrapped"), space, RecoveryCode.key("AAAA-AAAA-AAAA-AAAA-AAAA-AAAA", crypto), crypto)
            fail("otro código no abre")
        } catch (e: E2EEError.BadRecoveryCode) {}
    }

    @Test fun envelopeMatchesIOSAndFailsWhenTampered() {
        val space = v.getValue("space_id"); val id = v.getValue("entry_id"); val payload = v.getValue("payload").toByteArray()
        assertEquals(v.getValue("envelope"), Envelope.seal(payload, space, "entries", id, b("space_key"), fixed(b("envelope_nonce"))))
        assertArrayEquals(payload, Envelope.open(v.getValue("envelope"), space, "entries", id, b("space_key"), crypto))
        assertArrayEquals(payload, Envelope.open(v.getValue("envelope"), space.uppercase(), "entries", id.uppercase(), b("space_key"), crypto))
        fun fails(block: () -> Unit) = try { block(); fail("no debió abrir") } catch (e: E2EEError.CannotOpen) {}
        fails { Envelope.open(v.getValue("envelope"), "5a0f3c1e-8d2b-4c6a-9e7f-112233445567", "entries", id, b("space_key"), crypto) }
        fails { Envelope.open(v.getValue("envelope"), space, "recurring", id, b("space_key"), crypto) }
        fails { Envelope.open(v.getValue("envelope"), space, "entries", "e1000000-0000-4000-8000-000000000002", b("space_key"), crypto) }
        val bytes = b("envelope"); bytes[20] = (bytes[20].toInt() xor 1).toByte()
        fails { Envelope.open(E2EEFormat.b64(bytes), space, "entries", id, b("space_key"), crypto) }
        fails { Envelope.open(v.getValue("envelope"), space, "entries", id, b("recovery_key"), crypto) }
    }

    @Test fun pkceMatchesRFC7636AndIOS() {
        assertEquals("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", PKCE.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", crypto))
        assertEquals(v.getValue("pkce_challenge"), PKCE.challenge(v.getValue("pkce_verifier"), crypto))
        val verifier = PKCE.newVerifier(fixed(b("pkce_random48")))
        assertEquals(v.getValue("pkce_verifier48"), verifier)
        assertEquals(64, PKCE.newVerifier(crypto).length)
        assertTrue(PKCE.newVerifier(crypto).all { it.isLetterOrDigit() || it == '-' || it == '_' })
    }

    @Test fun serverTimeParsesPostgresAndFormatsMicros() {
        val t = ServerTime.parse("2026-11-08T10:00:00.123456+00:00")!!
        assertEquals("2026-11-08T10:00:00.123456Z", ServerTime.format(t))
        assertEquals("2026-11-08T15:00:00.500000Z", ServerTime.format(ServerTime.parse("2026-11-08 10:00:00.5-05:00")!!))
        assertEquals("2026-11-08T10:00:00.000000Z", ServerTime.format(ServerTime.parse("2026-11-08T10:00:00Z")!!))
        assertEquals("2026-11-08T08:30:00.000000Z", ServerTime.format(ServerTime.parse("2026-11-08T10:00:00+0130")!!))
        assertNull(ServerTime.parse("ayer"))
    }
}
