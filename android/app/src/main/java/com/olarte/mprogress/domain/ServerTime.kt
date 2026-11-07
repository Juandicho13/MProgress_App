package com.olarte.mprogress.domain

import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit

/**
 * Fechas como las manda y las espera Postgres (PostgREST): ISO 8601 con hasta 6 decimales de segundo, igual que
 * ios/MProgress/Domain/ServerTime.swift. Todo se maneja en microsegundos para que el cursor no repita filas.
 */
object ServerTime {
    /** "2026-11-08T10:00:00.123456+00:00", "2026-11-08T10:00:00Z", "2026-11-08 10:00:00.5-05:00". */
    fun parse(raw: String): Instant? {
        val text = raw.trim()
        if (text.length < 19) return null
        fun num(from: Int, to: Int) = text.substring(from, to).toIntOrNull()
        val year = num(0, 4); val month = num(5, 7); val day = num(8, 10); val hour = num(11, 13); val minute = num(14, 16); val second = num(17, 19)
        if (year == null || month == null || day == null || hour == null || minute == null || second == null) return null
        if (text[4] != '-' || text[7] != '-' || (text[10] != 'T' && text[10] != ' ') || text[13] != ':' || text[16] != ':') return null
        var index = 19
        var micros = 0L
        if (index < text.length && text[index] == '.') {
            index++
            val digits = StringBuilder()
            while (index < text.length && text[index].isDigit()) { digits.append(text[index]); index++ }
            micros = (digits.toString().padEnd(6, '0').take(6).toLongOrNull() ?: 0)
        }
        var offsetSeconds = 0
        if (index < text.length) {
            val sign = text[index]
            when (sign) {
                'Z', 'z' -> offsetSeconds = 0
                '+', '-' -> {
                    val rest = text.substring(index + 1).replace(":", "")
                    if (rest.length < 2) return null
                    val hours = rest.take(2).toIntOrNull() ?: return null
                    val minutes = if (rest.length >= 4) rest.substring(2, 4).toIntOrNull() ?: 0 else 0
                    offsetSeconds = (hours * 3600 + minutes * 60) * (if (sign == '-') -1 else 1)
                }
                else -> return null
            }
        }
        return try {
            LocalDateTime.of(year, month, day, hour, minute, second).toInstant(ZoneOffset.UTC).plusSeconds(-offsetSeconds.toLong()).plus(micros, ChronoUnit.MICROS)
        } catch (e: Exception) { null }
    }

    /** "2026-11-08T10:00:00.123456Z", siempre en UTC y con 6 decimales (redondea hacia abajo). */
    fun format(instant: Instant): String {
        val t = instant.truncatedTo(ChronoUnit.MICROS).atOffset(ZoneOffset.UTC)
        return "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ".format(t.year, t.monthValue, t.dayOfMonth, t.hour, t.minute, t.second, t.nano / 1000)
    }

    /** Ahora, en microsegundos (lo que guarda Postgres). */
    fun now(): Instant = Instant.now().truncatedTo(ChronoUnit.MICROS)
}
