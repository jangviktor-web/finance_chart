plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.finance.finance_chart"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.finance.finance_chart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // splits.abi 接管 abi 控制时，必须清空 ndk.abiFilters，否则 AGP 报
        // "ndk abiFilters cannot be present when splits abi filters are set" 冲突。
        ndk {
            abiFilters.clear()
        }
    }

    // 分架构打包：flutter build apk 默认产出 arm64-v8a / armeabi-v7a / x86_64 三个独立 APK，
    // universalApk=false 表示不再额外打全架构通用包（上架/分发只需发 arm64-v8a 包覆盖 99%+ 新机）。
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = false
        }
    }

    buildTypes {
        release {
            // TODO: 上架前必须替换为正式 release keystore（当前用 debug 签名仅便于本地调试）。
            // 配置方式：
            //   1. 生成 keystore：keytool -genkey -v -keystore release.jks -alias release -keyalg RSA -keysize 2048 -validity 10000
            //   2. 在 android/key.properties 填入 storeFile/storePassword/keyAlias/keyPassword
            //   3. 启用下方 signingConfigs.release 块并改为 signingConfig = signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("debug")
            // P0-1: 开启 R8 压缩/混淆（显著减小包体并防止简单反编译）
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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
