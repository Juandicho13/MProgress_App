package com.olarte.mprogress.ui.auto

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.olarte.mprogress.domain.Currency
import com.olarte.mprogress.domain.ReceiptParser
import com.olarte.mprogress.ui.components.*
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Radius
import com.olarte.mprogress.ui.theme.Spacing

/** Lee el texto de una imagen en el teléfono (ML Kit, sin internet) y devuelve las líneas. */
object ReceiptText {
    fun read(image: InputImage, onLines: (List<String>) -> Unit) {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(image)
            .addOnSuccessListener { text -> onLines(text.textBlocks.flatMap { b -> b.lines.map { it.text } }) }
            .addOnFailureListener { onLines(emptyList()) }
    }
}

/** Escanear recibo (F08-05): foto con la cámara o desde la galería; lee el total y el comercio en el teléfono. */
@Composable
fun ReceiptScanSheet(onDismiss: () -> Unit, onResult: (merchant: String?, amountMinor: Long?) -> Unit) {
    val context = LocalContext.current
    var camera by remember { mutableStateOf(false) }
    var working by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    fun handle(lines: List<String>) {
        working = false
        val total = ReceiptParser.total(lines, Currency.current)
        if (total == null) failed = true else onResult(ReceiptParser.merchant(lines), total)
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> if (ok) camera = true }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        working = true; failed = false
        runCatching { ReceiptText.read(InputImage.fromFilePath(context, uri), ::handle) }.onFailure { working = false; failed = true }
    }
    if (camera) {
        CameraCapture({ camera = false }, onTaken = { camera = false; working = true; failed = false }) { lines -> handle(lines) }
        return
    }
    OverlaySheet(onDismiss) {
        Column(Modifier.padding(horizontal = Spacing.margen).padding(bottom = Spacing.s4), verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            T("Escanear recibo", Type.titulo2, modifier = Modifier.padding(top = Spacing.s6))
            T("Leemos el total y el comercio en tu teléfono; la foto no sale de aquí ni se guarda.", Type.cuerpo2, Palette.texto2)
            if (working) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Palette.brasa, strokeWidth = 2.dp); T("Leyendo el recibo…", Type.cuerpo2, Palette.texto2)
            }
            if (failed) {
                T("No encontramos un total. Puedes escribirlo tú.", Type.cuerpo2, Palette.peligro)
                SecondaryButton("Escribirlo a mano") { onResult(null, null) }
            }
            Spacer(Modifier.height(Spacing.s8))
            PrimaryButton("Tomar foto") {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) camera = true
                else permission.launch(Manifest.permission.CAMERA)
            }
            SecondaryButton("Elegir de la galería") { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
        }
    }
}

/** Cámara a pantalla completa con CameraX: vista previa y botón para tomar la foto. */
@Composable
private fun CameraCapture(onCancel: () -> Unit, onTaken: () -> Unit, onLines: (List<String>) -> Unit) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val capture = remember { ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build() }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    DisposableEffect(Unit) { onDispose { provider?.unbindAll() } }
    androidx.activity.compose.BackHandler(onBack = onCancel)
    Box(Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Color.Black)) {
        AndroidView({ ctx ->
            PreviewView(ctx).also { view ->
                val future = ProcessCameraProvider.getInstance(ctx)
                future.addListener({
                    val p = future.get(); provider = p
                    val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
                    runCatching { p.unbindAll(); p.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, capture) }
                }, ContextCompat.getMainExecutor(ctx))
            }
        }, Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().padding(Spacing.s8).padding(bottom = 120.dp)) {
            Box(Modifier.fillMaxSize().clip(RoundedCornerShape(Radius.tarjeta)).background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.06f)))
        }
        Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(Spacing.margen).padding(bottom = Spacing.s6), verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            T("Pon el recibo dentro del marco", Type.cuerpo2, androidx.compose.ui.graphics.Color.White, Modifier.align(Alignment.CenterHorizontally))
            PrimaryButton("Tomar foto") {
                capture.takePicture(ContextCompat.getMainExecutor(context), object : ImageCapture.OnImageCapturedCallback() {
                    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
                    override fun onCaptureSuccess(image: ImageProxy) {
                        val media = image.image ?: run { image.close(); onCancel(); return }
                        val input = InputImage.fromMediaImage(media, image.imageInfo.rotationDegrees)
                        onTaken()
                        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(input)
                            .addOnSuccessListener { text -> onLines(text.textBlocks.flatMap { b -> b.lines.map { it.text } }) }
                            .addOnFailureListener { onLines(emptyList()) }
                            .addOnCompleteListener { image.close() }
                    }
                    override fun onError(exception: ImageCaptureException) = onCancel()
                })
            }
            SecondaryButton("Cancelar", onClick = onCancel)
        }
    }
}
