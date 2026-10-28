#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
[[ $(uname -s) == Darwin ]] || { echo 'Requires macOS and Xcode.' >&2; exit 1; }
ROOT=${1:?Usage: build-deps.sh absolute-build-directory}
mkdir -p "$ROOT"
ROOT=$(cd "$ROOT" && pwd)
PREFIX="$ROOT/prefix"
mkdir -p "$PREFIX/include" "$PREFIX/lib" "$ROOT/source" "$ROOT/objects"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
python3 "$SCRIPT_DIR/fetch-deps.py" "$ROOT/source"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC=$(xcrun --sdk iphoneos --find clang)
AR=$(xcrun --sdk iphoneos --find ar)
RANLIB=$(xcrun --sdk iphoneos --find ranlib)
MIN=${IOS_MIN_VERSION:-16.0}
FLAGS=(-arch arm64 -isysroot "$SDK" "-miphoneos-version-min=$MIN" -O2 -fPIC)


# Lua's own LUA_USE_IOS disables the unavailable system() API.
# popen/pclose are also unavailable on device: select Lua's unsupported fallback.
python3 - "$ROOT/source/lua-5.4.8/src/liolib.c" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = '#if defined(LUA_USE_POSIX)\t/* { */\n\n#define l_popen'
new = '#if defined(LUA_USE_POSIX) && !defined(LUA_USE_IOS) /* { */\n\n#define l_popen'
if old not in s:
    raise SystemExit('Lua popen patch no longer matches')
p.write_text(s.replace(old, new, 1))
PY
for source in "$ROOT/source/lua-5.4.8/src/"*.c; do
  case $(basename "$source") in lua.c|luac.c) continue ;; esac
  "$CC" "${FLAGS[@]}" -DLUA_USE_IOS -c "$source" -o "$ROOT/objects/$(basename "${source%.c}").o"
done
"$AR" rcs "$PREFIX/lib/liblua.a" "$ROOT/objects/"*.o
"$RANLIB" "$PREFIX/lib/liblua.a"
cp "$ROOT/source/lua-5.4.8/src/"*.h "$PREFIX/include/"
cp "$ROOT/source/lua-5.4.8/src/lua.hpp" "$PREFIX/include/"


(
  cd "$ROOT/source/openssl-openssl-3.5.4"
  export AR RANLIB
  export CC="xcrun --sdk iphoneos clang"
  export SDKROOT="$SDK"
  export CFLAGS="-isysroot $SDK"
  ./Configure ios64-xcrun no-shared no-tests no-module no-asm \
    "--prefix=$PREFIX" "--openssldir=$PREFIX/ssl" "-miphoneos-version-min=$MIN"
  make -j3 build_libs
  make install_dev
)


cmake -S "$ROOT/source/libgit2-1.9.0" -B "$ROOT/libgit2-build" \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 "-DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN" \
  -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF \
  -DBUILD_EXAMPLES=OFF -DUSE_SSH=OFF -DUSE_HTTPS=SecureTransport \
  -DUSE_BUNDLED_ZLIB=ON -DREGEX_BACKEND=builtin -DUSE_NTLMCLIENT=OFF \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build "$ROOT/libgit2-build" --parallel 3
cmake --install "$ROOT/libgit2-build"
echo "iOS static dependencies installed in $PREFIX"

