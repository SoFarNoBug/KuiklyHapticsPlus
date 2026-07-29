#!/usr/bin/env bash
#
# publish-ohos.sh
#
# 将本目录的鸿蒙源码包发布到 ohpm.openharmony.cn 的 @jlj scope。
#
# 流程：把源码打成带 `package/` 前缀的 .tgz（ohpm 要求所有内容置于
# package/ 目录内，且含 oh-package.json5 / README.md / LICENSE / CHANGELOG.md），
# 再执行 `ohpm publish <tgz>`。
#
# 前置条件（需你在本机自行执行，AI 不接触私钥/发布码）：
#   ohpm config set key_path ~/.ssh/ohpm_jlj        # 你的私钥路径
#   ohpm config set publish_id IRSSMQ8812           # 中心仓发布码
#   ohpm config set publish_registry https://ohpm.openharmony.cn/ohpm
#
# 用法：
#   bash publish-ohos.sh
#
set -euo pipefail

# 避免 macOS tar 把 AppleDouble 元数据（._*）打进包
export COPYFILE_DISABLE=1

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

PKG_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' oh-package.json5 | head -1 | sed 's/.*"\(.*\)".*/\1/')
PKG_VER=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' oh-package.json5 | head -1 | sed 's/.*"\(.*\)".*/\1/')
# 文件名里不允许含 '/'，把 @jlj/xxx 变成 @jlj-xxx
SAFE_NAME=$(echo "$PKG_NAME" | sed 's|/|-|g')

echo "[publish-ohos] package: ${PKG_NAME}@${PKG_VER}"
echo "[publish-ohos] cwd: $(pwd)"

# 1) 组装 package/ 目录（仅含发布所需文件，避免把 oh_modules/build/.git 打进去）
TMP=$(mktemp -d)
PKG_DIR="$TMP/package"
mkdir -p "$PKG_DIR"
cp oh-package.json5 README.md LICENSE CHANGELOG.md "$PKG_DIR/"
[ -f .ohpmignore ] && cp .ohpmignore "$PKG_DIR/"
[ -d src ] && cp -R src "$PKG_DIR/"

HAR="$DIR/${SAFE_NAME}-${PKG_VER}.har"
tar -czf "$HAR" -C "$TMP" package
rm -rf "$TMP"

echo "[publish-ohos] packed: $HAR"
echo "[publish-ohos] contents:"
tar -tzf "$HAR" | sort

# 2) 发布
echo "[publish-ohos] -> ohpm publish $HAR"
ohpm publish "$HAR"

echo "[publish-ohos] done."
