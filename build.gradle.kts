plugins {
    // trick: for the same plugin versions in all sub-modules
    id("com.android.application").version("8.3.2").apply(false)
    id("com.android.library").version("8.3.2").apply(false)
    kotlin("android").version("2.0.21-KBA-010").apply(false)
    kotlin("multiplatform").version("2.0.21-KBA-010").apply(false)
    id("com.google.devtools.ksp").version("2.1.21-2.0.1").apply(false)
    // Maven Central 发布（KMP 多 target / 签名 / POM / 上传）
    id("com.vanniktech.maven.publish").version("0.30.0").apply(false)
    id("org.jetbrains.dokka").version("1.9.20").apply(false)
}
