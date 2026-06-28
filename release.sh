#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT_DIR/DockWindowPreview.xcodeproj"
SCHEME="DockWindowPreview"
APP_NAME="Y-Dock"
VERSION="$(awk -F ' = ' '/MARKETING_VERSION = / { gsub(/;/, "", $2); print $2; exit }' "$ROOT_DIR/DockWindowPreview.xcodeproj/project.pbxproj")"
DERIVED_DATA="$ROOT_DIR/build/ReleaseDerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/$APP_NAME-v$VERSION.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-y-dock-notary}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
STAGE="$(mktemp -d "/tmp/Y-Dock-v$VERSION.XXXXXX")"

trap 'rm -rf "$STAGE"' EXIT

bold() { print -P "%B$1%b"; }

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "错误：找不到 Developer ID Application 证书。" >&2
  exit 1
fi

bold "▶ 0/7 检查公证凭据…"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<EOF
找不到公证凭据 profile：$NOTARY_PROFILE

请先使用 xcrun notarytool store-credentials 存入钥匙串，或通过环境变量指定：

  NOTARY_PROFILE=你的Profile ./release.sh
EOF
  exit 1
fi
echo "  ✓ 凭据就绪：$NOTARY_PROFILE"
echo "  ✓ 签名证书就绪：$SIGN_IDENTITY"

notarize() {
  local target="$1"
  local log
  log="$(mktemp)"
  if ! xcrun notarytool submit "$target" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1 | tee "$log"; then
    echo "✗ 公证提交失败：$target" >&2
    rm -f "$log"
    return 1
  fi

  local sid
  sid="$(grep -m1 -E "^[[:space:]]*id:" "$log" | awk '{print $2}')"
  if ! grep -q "status: Accepted" "$log"; then
    echo "✗ 公证未通过：$target" >&2
    [[ -n "$sid" ]] && xcrun notarytool log "$sid" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    rm -f "$log"
    return 1
  fi

  rm -f "$log"
  return 0
}

bold "▶ 1/7 Release 构建…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

bold "▶ 2/7 签名 app…"
rm -rf "$STAGE/$APP_NAME.app"
ditto --noextattr --norsrc "$BUILT_APP" "$STAGE/$APP_NAME.app"
xattr -cr "$STAGE/$APP_NAME.app"
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$STAGE/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$STAGE/$APP_NAME.app"
echo "  ✓ app 签名校验通过"

bold "▶ 3/7 打包 DMG…"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME v$VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"

bold "▶ 4/7 签名 DMG…"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=4 "$DMG_PATH"
echo "  ✓ DMG 签名校验通过"

bold "▶ 5/7 公证 DMG…"
notarize "$DMG_PATH"
echo "  ✓ DMG 已公证"

bold "▶ 6/7 装订 DMG 票据…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
echo "  ✓ DMG 已装订"

bold "▶ 7/7 Gatekeeper 验证…"
spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"

echo ""
bold "✅ 发布产物完成"
echo "可分发文件：$DMG_PATH"
ls -lh "$DMG_PATH"
