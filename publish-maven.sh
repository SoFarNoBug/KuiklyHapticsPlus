#!/bin/bash
#
# KuiklyHapticsPlus 发布脚本
#
# 目标（TARGET，默认 central）：
#   central -> Maven Central（io.github.sofarnobug，匿名分发，供其他开发者免凭证使用）
#   github  -> GitHub Packages（com.github.sofarnobug，自用兜底，已发布的旧产物保留）
#
# 用法：
#   TARGET=central ./publish-maven.sh
#   TARGET=github MAVEN_REPO_URL=... MAVEN_USERNAME=... MAVEN_PASSWORD=... ./publish-maven.sh
#
# Central 凭证（central.sonatype.com 的 User Token，不落盘，走环境变量）：
#   CENTRAL_USERNAME / CENTRAL_PASSWORD
#
# GPG 签名（不落盘；脚本运行时从本机 gpg 密钥环动态导出私钥注入 Gradle）：
#   GPG_KEY_ID       - 签名密钥指纹（默认 E03218FD37956AC6AE94223E041C34E7F024F7A0）
#   GPG_KEY_PASSWORD - 密钥口令（环境变量传入，不落盘）
#
# iOS Pod / 鸿蒙 HAR 单独发布：
#   - iOS ：cd KuiklyHapticsPlusIOS && pod trunk push KuiklyHapticsPlusIOS.podspec
#   - 鸿蒙：cd KuiklyHapticsPlusOhos && ohpm publish

set -e

BASE_VERSION="${MAVEN_VERSION:-0.0.1}"
KOTLIN_LIST=(${KOTLIN_VERSION_LIST:-2.1.21})
MODULE_KMP=KuiklyHapticsPlus
MODULE_ANDROID=KuiklyHapticsPlusAndroid
TARGET="${TARGET:-central}"

if [ "$TARGET" = "central" ]; then
  CENTRAL_USER="${CENTRAL_USERNAME:-}"
  CENTRAL_PASS="${CENTRAL_PASS:-${CENTRAL_PASSWORD:-}}"
  GPG_KEY_ID="${GPG_KEY_ID:-E03218FD37956AC6AE94223E041C34E7F024F7A0}"

  if [ -z "$CENTRAL_USER" ] || [ -z "$CENTRAL_PASS" ]; then
    echo "错误：请设置 CENTRAL_USERNAME / CENTRAL_PASSWORD（central.sonatype.com User Token）" >&2
    exit 1
  fi
  if [ -z "${GPG_KEY_PASSWORD:-}" ]; then
    echo "错误：请设置 GPG_KEY_PASSWORD（GPG 密钥口令，用于导出私钥与签名）" >&2
    exit 1
  fi

  # 运行时从密钥环导出 armored 私钥（仅存在于内存/环境变量，不落盘）
  SIGNING_KEY=$(gpg --batch --pinentry-mode loopback --passphrase "$GPG_KEY_PASSWORD" \
    --armor --export-secret-keys "$GPG_KEY_ID")
  if [ -z "$SIGNING_KEY" ]; then
    echo "错误：导出 GPG 私钥失败，请检查 GPG_KEY_ID / GPG_KEY_PASSWORD" >&2
    exit 1
  fi
  export ORG_GRADLE_PROJECT_signingInMemoryKey="$SIGNING_KEY"
  export ORG_GRADLE_PROJECT_signingInMemoryKeyPassword="$GPG_KEY_PASSWORD"

  for kt in "${KOTLIN_LIST[@]}"; do
    BV="${BASE_VERSION}-${kt}"
    echo "=============================================="
    echo "Publishing to Maven Central -> ${BV}"
    echo "=============================================="
    ./gradlew publishAllPublicationsToMavenCentralRepository \
      -PmavenVersion="${BV}" -PkotlinVersion="${kt}" \
      -PmavenCentralUsername="${CENTRAL_USER}" -PmavenCentralPassword="${CENTRAL_PASS}"
  done
  echo "Maven Central 发布完成：io.github.sofarnobug:kuiklyhapticsplus / kuiklyhapticsplusandroid"
else
  REPO_URL="${MAVEN_REPO_URL:-https://maven.pkg.github.com/SoFarNoBug/KuiklyHapticsPlus}"
  USERNAME="${MAVEN_USERNAME:-}"
  PASSWORD="${MAVEN_PASSWORD:-}"
  for kt in "${KOTLIN_LIST[@]}"; do
    BV="${BASE_VERSION}-${kt}"
    echo "=============================================="
    echo "Publishing to GitHub Packages -> ${BV}"
    echo "=============================================="
    ./gradlew ":${MODULE_KMP}:publish" ":${MODULE_ANDROID}:publish" \
      -PmavenVersion="${BV}" -PkotlinVersion="${kt}" \
      -PmavenRepoUrl="${REPO_URL}" -PmavenUsername="${USERNAME}" -PmavenPassword="${PASSWORD}"
  done
  echo "GitHub Packages 发布完成：com.github.sofarnobug:kuiklyhapticsplus / kuiklyhapticsplusandroid"
fi
