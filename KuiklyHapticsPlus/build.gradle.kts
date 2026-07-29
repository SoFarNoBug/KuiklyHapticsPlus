import com.vanniktech.maven.publish.SonatypeHost

plugins {
    kotlin("multiplatform")
    id("com.android.library")
    id("org.jetbrains.dokka")
    id("com.vanniktech.maven.publish")
}

val mavenVersion: String = findProperty("mavenVersion") as? String
    ?: findProperty("MAVEN_VERSION") as? String
    ?: "0.0.2"
val groupId: String = findProperty("groupId") as? String
    ?: findProperty("GROUP_ID") as? String
    ?: "com.jlj.kuiklybase"

group = groupId
version = mavenVersion

// 可选：保留 GitHub Packages 发布能力（仅当显式传入 mavenRepoUrl 时启用，不影响 Central 发布）
publishing {
    repositories {
        val gpUrl = findProperty("mavenRepoUrl") as? String
        if (!gpUrl.isNullOrBlank()) {
            maven {
                url = uri(gpUrl)
                credentials {
                    username = findProperty("mavenUsername") as? String ?: ""
                    password = findProperty("mavenPassword") as? String ?: ""
                }
            }
        }
    }
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "1.8"
            }
        }
        publishLibraryVariants("release")
    }

    js(IR) {
        browser()
        binaries.executable()
    }

    iosX64()
    iosArm64()
    iosSimulatorArm64()

    ohosArm64 {
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                compileOnly("com.tencent.kuikly-open:core:${Version.getKuiklyOhosVersion()}")
                compileOnly("com.tencent.kuikly-open:core-annotations:${Version.getKuiklyOhosVersion()}")
                // LocalHapticsModule 依赖 Compose runtime（androidx.compose.runtime.*），仅编译期、不传递
                compileOnly("com.tencent.kuikly-open:compose:${Version.getKuiklyOhosVersion()}")
            }
        }

        val androidMain by getting {
            dependencies {
                compileOnly("com.tencent.kuikly-open:core-render-android:${Version.getKuiklyOhosVersion()}")
            }
        }
        val iosX64Main by getting
        val iosArm64Main by getting
        val iosSimulatorArm64Main by getting
        val iosMain by creating {
            dependsOn(commonMain)
            iosX64Main.dependsOn(this)
            iosArm64Main.dependsOn(this)
            iosSimulatorArm64Main.dependsOn(this)
        }
    }
}

android {
    namespace = "com.jlj.kuiklybase.haptics"
    compileSdk = 34
    defaultConfig {
        minSdk = 21
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}

// ---- Maven Central 发布（vanniktech 统一接管：坐标 / POM / 签名 / 上传）----
mavenPublishing {
    coordinates("io.github.sofarnobug", "kuiklyhapticsplus", project.version.toString())
        publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
        if (System.getenv("SKIP_SIGN") != "1") signAllPublications()

    pom {
        name.set("KuiklyHapticsPlus")
        description.set("跨端手机震动 / 触感反馈 Kuikly Module（KMP：Android / iOS / JS）")
        url.set("https://github.com/SoFarNoBug/KuiklyHapticsPlus")
        licenses {
            license {
                name.set("MIT")
                url.set("https://opensource.org/licenses/MIT")
            }
        }
        developers {
            developer {
                id.set("sofarnobug")
                name.set("SoFarNoBug")
            }
        }
        scm {
            url.set("https://github.com/SoFarNoBug/KuiklyHapticsPlus")
            connection.set("scm:git:git://github.com/SoFarNoBug/KuiklyHapticsPlus.git")
            developerConnection.set("scm:git:ssh://git@github.com/SoFarNoBug/KuiklyHapticsPlus.git")
        }
    }
}
