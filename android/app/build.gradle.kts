import java.util.Properties
import java.io.FileInputStream

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

    // 分架构打包：开启后会产出 arm64-v8a / armeabi-v7a / x86_64 三个独立 APK。
    //
    // 开关由 Gradle 属性 split-per-abi 控制（flutter build apk --split-per-abi
    // 会自动传入 -Psplit-per-abi=true）。CI 用此开关实现「1 通用包 + 3 分架构包 = 4 APK」：
    //   - 第一步 `flutter build apk --release` 不带该属性 → isEnable=false → 仅产通用包；
    //   - 第二步 `--split-per-abi` → isEnable=true → 产 3 个分架构包。
    // 通用包由第一步产出，故此处 universalApk 固定为 false，避免第二步额外再产通用包造成重复。
    val enableAbiSplits = project.hasProperty("split-per-abi") &&
            project.property("split-per-abi").toString().toBoolean()
    splits {
        abi {
            isEnable = enableAbiSplits
            isUniversalApk = false
        }
    }

    // —— 正式签名（CI 自动发布用）——
    // 读取 android/key.properties（已被 .gitignore 忽略，不会进仓库）。
    // 本地无 key.properties 时回退 debug 签名，保证本地 `flutter build apk --release` 不受影响。
    val keystorePropsFile = rootProject.file("key.properties")
    val keystoreProps = Properties()
    if (keystorePropsFile.exists()) {
        keystoreProps.load(FileInputStream(keystorePropsFile))
    }
    val hasReleaseKey = keystorePropsFile.exists() &&
            keystoreProps["storeFile"] != null &&
            keystoreProps["keyAlias"] != null &&
            keystoreProps["storePassword"] != null &&
            keystoreProps["keyPassword"] != null

    if (hasReleaseKey) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
                val st = keystoreProps["storeType"]
                if (st != null) storeType = st as String
            }
        }
    }

    buildTypes {
        release {
            // CI 有 key.properties（由 GitHub Actions 从 Secrets 写入）→ 用正式 keystore 签名；
            // 本地无 key.properties → 回退 debug 签名，便于调试。
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
