import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional applicationId suffix (e.g. "pr123") set via the APPLICATION_ID_SUFFIX env
// var so test builds install side by side with production. Suffixed builds are
// signed with the staging key instead of the production key.
val idSuffix = System.getenv("APPLICATION_ID_SUFFIX")?.takeIf { it.isNotBlank() }

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.globalbibletools.gbt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.globalbibletools.gbt" + (idSuffix?.let { ".$it" } ?: "")
        manifestPlaceholders["appLabel"] = if (idSuffix != null) "GBT ($idSuffix)" else "GBT"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Throwaway key committed to the repo (app/staging.jks) for suffixed test
        // builds. Intentionally public: it never signs anything distributed to
        // users, and it lets CI (including fork PRs) build without access to the
        // production keystore. A stable key also lets updated test builds install
        // over previously installed ones instead of failing on signature mismatch.
        create("staging") {
            keyAlias = "staging"
            keyPassword = "staging"
            storeFile = rootProject.file("app/staging.jks")
            storePassword = "staging"
        }
        // Production key from android/key.properties (never committed).
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (idSuffix != null) {
                signingConfigs.getByName("staging")
            } else {
                signingConfigs.findByName("release")
                    ?: throw GradleException(
                        "Production builds require android/key.properties (release keystore)."
                    )
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
