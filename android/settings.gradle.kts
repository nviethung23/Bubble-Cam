pluginManagement {
    // Đọc flutter.sdk từ local.properties
    val flutterSdkPath = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        val path = props.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }

    // BẮT BUỘC: include Flutter plugin loader từ SDK
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Khai báo version plugin (apply false ở đây; apply trong module :app)
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false

    // FlutterFire / Google Services (nên nâng 4.4.2)
    id("com.google.gms.google-services") version "4.4.2" apply false
}

// Repos dùng để resolve dependencies của các modules
dependencyResolutionManagement {
     repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "bubblecam"
include(":app")
