import java.util.Properties

// Credenciais de assinatura. O arquivo fica fora do controle de versão: sem ele
// (num clone novo, por exemplo) o release cai para a chave de debug e o build
// continua rodando — só não serve para publicar.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystoreProperties.containsKey("storeFile")

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.viniciusgabriel.ondeparei"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("upload") {
            if (hasUploadKey) {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    defaultConfig {
        // Identidade do app nas lojas. É imutável depois do primeiro envio.
        applicationId = "com.viniciusgabriel.ondeparei"
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // NDK Configuration
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                // Chave de debug: a Play recusa um pacote assinado assim.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
