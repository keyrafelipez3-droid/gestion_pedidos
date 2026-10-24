import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de la APK de publicación. Los datos de la llave van en
// android/key.properties (NO se sube a GitHub, ver android/.gitignore).
// Si el archivo no existe, se firma con la llave de pruebas (debug).
val llaveProps = Properties()
val llaveArchivo = rootProject.file("key.properties")
if (llaveArchivo.exists()) {
    llaveProps.load(FileInputStream(llaveArchivo))
}

android {
    namespace = "com.univalle.gestion_pedidos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.univalle.gestion_pedidos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (llaveArchivo.exists()) {
                keyAlias = llaveProps["keyAlias"] as String
                keyPassword = llaveProps["keyPassword"] as String
                storeFile = file(llaveProps["storeFile"] as String)
                storePassword = llaveProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (llaveArchivo.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
