package com.olarte.mprogress.ui.settings

import android.content.SharedPreferences
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.domain.LockDelay
import com.olarte.mprogress.ui.components.FormRow
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette

/** Fila "Bloquear" de Ajustes, debajo de Bloqueo con huella o rostro: Inmediatamente, después de 30 segundos o de 1 minuto. Por dispositivo. */
@Composable
fun LockDelayRow(prefs: SharedPreferences, startsOpen: Boolean = false) {
    var delay by remember { mutableStateOf(LockDelay.from(prefs.getInt(LockDelay.STORAGE_KEY, 0))) }
    var open by remember { mutableStateOf(startsOpen) }
    Box {
        FormRow("Bloquear", delay.title, onClick = { open = true })
        DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
            LockDelay.entries.forEach { option ->
                DropdownMenuItem(
                    { T(option.title, Type.cuerpo, if (option == delay) Palette.brasaTinta else Palette.texto1) },
                    {
                        prefs.edit().putInt(LockDelay.STORAGE_KEY, option.seconds).apply()
                        delay = option
                        open = false
                    },
                    trailingIcon = { if (option == delay) Icon(Icons.Rounded.Check, null, Modifier.size(18.dp), tint = Palette.brasaTinta) },
                )
            }
        }
    }
}
