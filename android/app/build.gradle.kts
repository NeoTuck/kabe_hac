import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingFile.exists()) signingFile.inputStream().use { load(it) }
}
val hasProductionSigning = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !signingProperties.getProperty(it).isNullOrBlank() }
val technicalPilot = System.getenv("KABE_TECHNICAL_PILOT") == "true"

// Flutter plugins still request DataStore 1.1.7 and MapLibre OpenGL 13.5.0.
// Resolve the app's compile/runtime graph to the reviewed native AAR versions
// without changing the plugins' Dart package versions or their cached sources.
configurations.configureEach {
    resolutionStrategy.eachDependency {
        if (requested.group == "androidx.datastore") {
            useVersion("1.2.1")
            because("Use the same DataStore release across its atomic artifact group for 16 KB native review")
        }
        if (requested.group == "org.maplibre.gl" && requested.name == "android-sdk-opengl") {
            useVersion("13.5.3")
            because("Use the reviewed OpenGL AAR for 16 KB native review")
        }
    }
}

val productionContentGate = tasks.register<Exec>("productionContentGate") {
    commandLine("sh", rootProject.file("../tools/production_build_gate.sh").absolutePath)
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(productionContentGate)
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release", ignoreCase = true) } &&
        !hasProductionSigning && !technicalPilot) {
        throw GradleException("Production release requires android/key.properties. Debug signing is allowed only for KABE_TECHNICAL_PILOT=true technical CI artifacts.")
    }
}

android {
    namespace = "com.mustafasenoglu.hac_umre_sesli_rehber"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mustafasenoglu.hac_umre_sesli_rehber"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasProductionSigning) {
            create("production") {
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasProductionSigning -> signingConfigs.getByName("production")
                technicalPilot -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
