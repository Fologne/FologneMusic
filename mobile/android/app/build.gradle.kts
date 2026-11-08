import java.security.MessageDigest

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystore = providers.environmentVariable("FOLOGNE_KEYSTORE")
val releasePassword = providers.environmentVariable("FOLOGNE_KEYSTORE_PASSWORD")
val experimentalDownloads = providers.environmentVariable("FOLOGNE_EXPERIMENTAL_DOWNLOADS").orNull == "true"

if (experimentalDownloads) {
    val zipapp = file(providers.environmentVariable("FOLOGNE_YTDLP_ZIPAPP").get())
    check(zipapp.isFile) { "FOLOGNE_YTDLP_ZIPAPP precisa apontar para um arquivo." }
    val stagedAssets = layout.buildDirectory.dir("experimental-download-assets")
    val stageExtractor = tasks.register<Copy>("stageDownloadExtractor") {
        from(zipapp)
        into(stagedAssets)
        rename { "fologne-yt-dlp" }
        doFirst {
            val sha256 = MessageDigest.getInstance("SHA-256")
                .digest(zipapp.readBytes()).joinToString("") { "%02x".format(it) }
            check(sha256 == "e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3") {
                "Use o zipapp oficial yt-dlp 2026.10.26."
            }
        }
    }
    tasks.matching { it.name == "preBuild" }.configureEach { dependsOn(stageExtractor) }
    android.sourceSets.named("main") { assets.srcDir(stagedAssets.get().asFile) }
    dependencies {
        implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
        implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
    }
}

android {
    namespace = "com.musicapp.music_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    sourceSets.named("main") {
        java.srcDir(if (experimentalDownloads) "src/downloads/kotlin" else "src/noDownloads/kotlin")
    }
    if (experimentalDownloads) {
        packaging.jniLibs.useLegacyPackaging = true
        packaging.jniLibs.keepDebugSymbols += setOf("**/libffmpeg.zip.so", "**/libpython.zip.so")
        packaging.jniLibs.excludes += setOf("**/armeabi-v7a/**", "**/x86/**")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.musicapp.music_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseKeystore.isPresent && releasePassword.isPresent) {
                storeFile = file(releaseKeystore.get())
                storeType = "PKCS12"
                storePassword = releasePassword.get()
                keyAlias = "folognemusic"
                keyPassword = releasePassword.get()
            }
        }
    }
    buildTypes {
        if (experimentalDownloads) {
            debug {
                applicationIdSuffix = ".qa"
            }
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            if (experimentalDownloads) {
                proguardFile("proguard-downloads.pro")
            }
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(releaseKeystore.isPresent && releasePassword.isPresent) {
            "Configure FOLOGNE_KEYSTORE e FOLOGNE_KEYSTORE_PASSWORD para assinar o APK."
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
