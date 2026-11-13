#!/bin/bash
# Builds Wisp.app; --preview produces an isolated Chinese preview app.
set -euo pipefail
cd "$(dirname "$0")/.."

config=release
archs=(--arch arm64 --arch x86_64)
preview=false
for option in "$@"; do
    case "$option" in
        --debug) config=debug; archs=() ;;
        --native) archs=() ;;
        --preview) preview=true ;;
        *) echo "Unknown option: $option" >&2; exit 1 ;;
    esac
done

version=$(sed -n 's/.*version = "\(.*\)".*/\1/p' Sources/WispCore/Support/Wisp.swift)
build_number=$(git rev-list --count HEAD 2>/dev/null || echo 1)
swift build -c "$config" --jobs 2 ${archs[@]+"${archs[@]}"} --product WispApp
swift build -c "$config" --jobs 2 ${archs[@]+"${archs[@]}"} --product wisp
bin=$(swift build -c "$config" ${archs[@]+"${archs[@]}"} --show-bin-path)

app=build/Wisp.app
if $preview; then app=build/Wisp中文预览.app; fi
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
cp "$bin/WispApp" "$app/Contents/MacOS/Wisp"
cp "$bin/wisp" "$app/Contents/Helpers/wisp"
cp -R "$bin/Wisp_WispCore.bundle" "$app/Contents/Resources/"
sed -e "s/__VERSION__/$version/" -e "s/__BUILD__/$build_number/" Resources/Info.plist > "$app/Contents/Info.plist"
if $preview; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier app.wisp.Wisp.zh-hans-preview' "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName Wisp中文预览' "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Wisp中文预览' "$app/Contents/Info.plist"
fi
if [[ -f Resources/Wisp.icns ]]; then cp Resources/Wisp.icns "$app/Contents/Resources/Wisp.icns"; fi
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/LICENSE"
codesign --force --options runtime --sign - "$app/Contents/Helpers/wisp"
codesign --force --options runtime --sign - "$app"
echo "$app"
