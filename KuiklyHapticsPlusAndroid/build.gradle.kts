import com.vanniktech.maven.publish.SonatypeHost

plugins {
    id("com.android.library")
    kotlin("android")
    id("com.vanniktech.maven.publish")
}

val mavenVersion: String = findProperty("mavenVersion") as? String
    ?: findProperty("MAVEN_VERSION") as? String
    ?: "0.0.1"
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

android {
    namespace = "com.jlj.kuiklybase.haptics.android"
    compileSdk = 34
    defaultConfig {
        minSdk = 21
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    compileOnly("com.tencent.kuikly-open:core-render-android:${Version.getKuiklyVersion()}")
    implementation("androidx.appcompat:appcompat:1.2.0")
    implementation("androidx.core:core-ktx:1.6.0")
}

// ---- Maven Central 发布（vanniktech 统一接管：坐标 / POM / 签名 / 上传）----
mavenPublishing {
    coordinates("io.github.sofarnobug", "kuiklyhapticsplusandroid", project.version.toString())
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
    signAllPublications()

    pom {
        name.set("KuiklyHapticsPlusAndroid")
        description.set("KuiklyHapticsPlus 的 Android 原生实现层（KRVibrateModule）")
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
