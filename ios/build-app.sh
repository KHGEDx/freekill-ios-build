#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
SRC=${1:?Usage: build-app.sh source-directory output-directory}
OUT=${2:?Missing output directory}
: "${QT_IOS_ROOT:?Missing Qt for iOS directory}"
: "${QT_HOST_PATH:?Missing matching Qt desktop tools}"
: "${FK_IOS_DEPS:?Missing arm64 iOS dependency prefix}"
[[ -x "$QT_IOS_ROOT/bin/qt-cmake" ]] || { echo 'Qt iOS qt-cmake missing'; exit 1; }
[[ -x "$QT_HOST_PATH/bin/qsb" ]] || { echo 'Qt desktop qsb missing'; exit 1; }
MIN=${IOS_MIN_VERSION:-16.0}
cmake -S "$SRC" -B "$SRC/build-ios" -G Xcode \
  "-DCMAKE_TOOLCHAIN_FILE=$QT_IOS_ROOT/lib/cmake/Qt6/qt.toolchain.cmake" \
  "-DQT_HOST_PATH=$QT_HOST_PATH" "-DFK_IOS_DEPS=$FK_IOS_DEPS" \
  -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
  "-DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN" \
  "-DOPENSSL_ROOT_DIR=$FK_IOS_DEPS" -DOPENSSL_USE_STATIC_LIBS=TRUE \
  "-DLUA_INCLUDE_DIR=$FK_IOS_DEPS/include" \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build "$SRC/build-ios" --config Release --parallel 3 -- \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
APP="$SRC/build-ios/Release-iphoneos/FreeKill.app"
[[ -d "$APP" ]] || { echo "Expected device app not found: $APP" >&2; exit 1; }
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
python3 "$SCRIPT_DIR/prepare-assets.py" "$SRC" "$APP/fk-data" "$QT_HOST_PATH"
python3 "$SCRIPT_DIR/package-ipa.py" "$APP" "$OUT" "$SRC"
