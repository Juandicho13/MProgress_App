package com.olarte.mprogress

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Size
import com.olarte.mprogress.ui.theme.Spacing

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { RootScreen() }
    }
}

enum class AppTab(val title: String) {
    Inicio("Inicio"), Resumen("Resumen"), Dinero("Dinero"), Calendario("Calendario"), Ajustes("Ajustes")
}

@Composable
fun RootScreen() {
    var tab by remember { mutableStateOf(AppTab.Inicio) }
    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.fondo)
    ) {
        Column(
            Modifier
                .statusBarsPadding()
                .padding(horizontal = Spacing.margen, vertical = Spacing.s8)
        ) {
            Text(tab.title, color = Palette.texto1, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text("MProgress · F00", color = Palette.texto2, fontSize = 14.sp)
        }
        GlassTabBar(
            selected = tab,
            onSelect = { tab = it },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(horizontal = Spacing.s4, vertical = Spacing.s2)
        )
    }
}

@Composable
fun GlassTabBar(selected: AppTab, onSelect: (AppTab) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .height(Size.barra)
            .clip(CircleShape)
            .background(Palette.vidrio)
            .border(1.dp, Color.White.copy(alpha = 0.12f), CircleShape)
            .padding(Spacing.s2),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        AppTab.entries.forEach { item ->
            val active = item == selected
            Box(
                Modifier
                    .weight(1f)
                    .height(Size.toqueMinimo)
                    .clip(CircleShape)
                    .background(if (active) Color.White.copy(alpha = 0.12f) else Color.Transparent)
                    .clickable { onSelect(item) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    item.title,
                    color = if (active) Palette.brasa else Palette.texto2,
                    fontSize = 11.sp,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium
                )
            }
        }
    }
}

@Preview
@Composable
private fun RootPreview() {
    RootScreen()
}
