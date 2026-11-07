import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeCompiler)
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

android {
    namespace = "com.olarte.mprogress"
    compileSdk = libs.versions.android.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "com.olarte.mprogress"
        minSdk = libs.versions.android.minSdk.get().toInt()
        targetSdk = libs.versions.android.targetSdk.get().toInt()
        versionCode = 13
        versionName = "1.2"
    }
    // estandar: la que Juan descarga e instala por archivo; sin SMS ni lector de notificaciones, porque Play Protect la bloquea.
    // completo: todo el registro automático; se instala desde el Mac (Android Studio o ADB). Mismo applicationId: los datos se conservan.
    flavorDimensions += "captura"
    productFlavors {
        create("estandar") {
            dimension = "captura"
            isDefault = true
            buildConfigField("boolean", "CAPTURA_COMPLETA", "false")
        }
        create("completo") {
            dimension = "captura"
            buildConfigField("boolean", "CAPTURA_COMPLETA", "true")
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all { it.systemProperty("roborazzi.test.record", "true") }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

// Con dos versiones, AGP ya no crea testDebugUnitTest: se deja como atajo a las pruebas de la estándar.
tasks.register("testDebugUnitTest") { dependsOn("testEstandarDebugUnitTest") }

dependencies {
    implementation(libs.androidx.activity.compose)
    implementation(libs.compose.runtime)
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.coroutines.android)
    implementation(libs.compose.icons)
    implementation(libs.androidx.biometric)
    implementation(libs.camera.camera2)
    implementation(libs.camera.lifecycle)
    implementation(libs.camera.view)
    implementation(libs.mlkit.text)
    implementation(libs.tink.android)
    implementation(libs.glance.appwidget)
    implementation(libs.compose.uiToolingPreview)
    debugImplementation(libs.compose.uiTooling)
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.androidx.test.core)
}
