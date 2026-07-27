#!/bin/bash
#
# KuiklyHapticsPlus 发布脚本（改编自 KuiklySensors publish-maven.sh）
#
# 发布 Maven 模块（KMP 公共层 + Android 原生层）：
#   com.jlj.kuiklybase:KuiklyHapticsPlus:0.0.1-<kotlinVersion>
#   com.jlj.kuiklybase:KuiklyHapticsPlusAndroid:0.0.1-<kotlinVersion>
#
# 用法：
#   ./publish-maven.sh
# 或单独指定版本：
#   MAVEN_VERSION=0.0.1 ./publish-maven.sh
#
# 环境变量（可选，缺省读取 gradle.properties）：
#   MAVEN_REPO_URL / MAVEN_USERNAME / MAVEN_PASSWORD
#
# iOS Pod / 鸿蒙 HAR 单独发布：
#   - iOS ：cd KuiklyHapticsPlusIOS && pod trunk push KuiklyHapticsPlusIOS.podspec
#   - 鸿蒙：cd KuiklyHapticsPlusOhos && ohpm publish

set -e

BASE_VERSION="${MAVEN_VERSION:-0.0.1}"
REPO_URL="${MAVEN_REPO_URL:-https://mirrors.tencent.com/repository/maven/kuikly-open/}"
USERNAME="${MAVEN_USERNAME:-}"
PASSWORD="${MAVEN_PASSWORD:-}"

# Kotlin 版本列表（KMP / Android）
KOTLIN_LIST=(${KOTLIN_VERSION_LIST:-2.1.21})
# 鸿蒙 Kotlin 版本列表（如需发布鸿蒙 KMP 产物）
OHOS_KOTLIN_LIST=(${OHOS_KOTLIN_VERSION_LIST:-2.0.21-ohos})

MODULE_KMP=KuiklyHapticsPlus
MODULE_ANDROID=KuiklyHapticsPlusAndroid

publish_module() {
  local module="$1"
  local kt_version="$2"
  local build_version="${BASE_VERSION}-${kt_version}"
  echo "=============================================="
  echo "Publishing :${module} -> ${build_version}"
  echo "=============================================="
  ./gradlew ":${module}:publish" \
    -PmavenRepoUrl="${REPO_URL}" \
    -PmavenUsername="${USERNAME}" \
    -PmavenPassword="${PASSWORD}" \
    -PmavenVersion="${build_version}" \
    -PkotlinVersion="${kt_version}"
}

# 1) KMP 公共层 + Android 原生层（按 Kotlin 版本列表发布）
for kt in "${KOTLIN_LIST[@]}"; do
  publish_module "${MODULE_KMP}" "${kt}"
  publish_module "${MODULE_ANDROID}" "${kt}"
done

# 2) 鸿蒙产物（如需）
for kt in "${OHOS_KOTLIN_LIST[@]}"; do
  echo "[ohos] 鸿蒙 KMP 产物发布暂未启用（如需请补充 KuiklyHapticsPlusOhos Gradle 模块）。"
done

echo "Maven 发布完成。iOS Pod / 鸿蒙 HAR 请按脚本顶部说明单独发布。"
