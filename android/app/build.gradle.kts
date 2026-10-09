plugins {
    id("com.android.application")
    // Flutter Gradle Plugin phải được áp dụng sau Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.vku_expense_ocr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.vku_expense_ocr"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Tạm dùng debug signing để kiểm tra bản Release.
            // Cần cấu hình keystore riêng trước khi nộp chính thức.
            signingConfig = signingConfigs.getByName("debug")

            // Tắt R8 để tránh lỗi thiếu class của ML Kit.
            isMinifyEnabled = false

            // Không loại bỏ resource khi chưa bật minification.
            isShrinkResources = false
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
