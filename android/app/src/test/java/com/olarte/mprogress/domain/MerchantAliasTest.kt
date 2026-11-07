package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Nombres de comercios, con las mismas pruebas de MerchantAliasTests de iOS. */
class MerchantAliasTest {
    private val salidas = "0a000000-0000-4000-8000-000000000008"

    @Test fun normalizar() {
        assertEquals("PEPEPOLLO", MerchantAliasMath.normalize("PEPEPOLLO SAS 123"))
        assertEquals("PEPEPOLLO", MerchantAliasMath.normalize("Pepepollo S.A.S."))
        assertEquals("CREPES WAFFLES", MerchantAliasMath.normalize("  Crepes & Waffles   Ltda "))
        assertEquals("ALMACEN EXITO", MerchantAliasMath.normalize("Almacén Éxito Bogotá D.C. #45"))
        assertEquals("PANADERIA LA ESPANOLA", MerchantAliasMath.normalize("PANADERÍA LA ESPAÑOLA CO"))
        assertEquals("MCDONALDS", MerchantAliasMath.normalize("MC'DONALDS COL"))
        assertEquals("RAPPI RESTAURANTE", MerchantAliasMath.normalize("RAPPI*RESTAURANTE-12"))
    }

    @Test fun soloRuido() {
        assertEquals("SAS", MerchantAliasMath.normalize("SAS"))
        assertEquals("", MerchantAliasMath.normalize("1234 *"))
    }

    @Test fun buscar() {
        val rules = listOf(
            MerchantAliasRule(key = "PEPEPOLLO", name = "El Corral", categoryId = salidas),
            MerchantAliasRule(key = "EXITO", name = "Éxito"),
            MerchantAliasRule(key = "EXITO EXPRESS", name = "Éxito Express"),
        )
        assertEquals("El Corral", MerchantAliasMath.match("PEPEPOLLO SAS 123", rules)?.name)
        assertEquals("Éxito", MerchantAliasMath.match("Exito Calle 80", rules)?.name)
        assertEquals("Éxito Express", MerchantAliasMath.match("EXITO EXPRESS CRA 7", rules)?.name)
        assertNull(MerchantAliasMath.match("EXITOSO", rules))
        assertNull(MerchantAliasMath.match("Otro", rules))
        assertNull(MerchantAliasMath.match(null, rules))
    }

    @Test fun llenar() {
        val rules = listOf(MerchantAliasRule(key = "PEPEPOLLO", name = "El Corral", categoryId = salidas))
        assertEquals("El Corral" to salidas, MerchantAliasMath.prefill("Pepepollo Sas 99", rules))
        assertEquals("Farmatodo" to null, MerchantAliasMath.prefill("Farmatodo", rules))
    }

    @Test fun aprender() {
        val rule = MerchantAliasMath.learn("PEPEPOLLO SAS 123", true, " El Corral ", salidas)!!
        assertEquals("PEPEPOLLO", rule.key); assertEquals("El Corral", rule.name); assertEquals(salidas, rule.categoryId)
        assertNull(MerchantAliasMath.learn("PEPEPOLLO SAS", false, "El Corral", null))
        assertNull(MerchantAliasMath.learn(null, true, "El Corral", null))
        assertNull(MerchantAliasMath.learn("Pepepollo Sas", true, "PEPEPOLLO", null))
        assertEquals("Pepepollo", MerchantAliasMath.learn("Pepepollo Sas", true, "Pepepollo", salidas)?.name)
        assertNull(MerchantAliasMath.learn("Pepepollo", true, "  ", salidas))
    }
}
