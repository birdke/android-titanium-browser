#!/bin/bash
set -euo pipefail

source common.sh

if [[ -z "${LOCAL_TEST_JKS:-}" || -z "${STORE_TEST_JKS:-}" ]]; then
  echo "LOCAL_TEST_JKS and STORE_TEST_JKS GitHub secrets are required" >&2
  exit 2
fi

set_keys
trap 'rm -rf "$SCRIPT_DIR/keys"' EXIT

export VERSION
VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' vanadium/args.gn)
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive
export GIT_COMMITTER_NAME="Titanium x86_64 Actions"
export GIT_COMMITTER_EMAIL="actions@users.noreply.github.com"

TITANIUM_BUILD_CACHE_DIR=${TITANIUM_BUILD_CACHE_DIR:-$SCRIPT_DIR/.build-cache}
TITANIUM_BUILD_JOBS=${TITANIUM_BUILD_JOBS:-3}
mkdir -p "$TITANIUM_BUILD_CACHE_DIR"/{cipd,tmp,vpython,xdg}
export CIPD_CACHE_DIR="$TITANIUM_BUILD_CACHE_DIR/cipd"
export VPYTHON_VIRTUALENV_ROOT="$TITANIUM_BUILD_CACHE_DIR/vpython"
export XDG_CACHE_HOME="$TITANIUM_BUILD_CACHE_DIR/xdg"
export TMPDIR="$TITANIUM_BUILD_CACHE_DIR/tmp"

sudo apt-get update
sudo apt-get install -y sudo lsb-release file nano git curl python3 python3-pillow imagemagick librsvg2-bin unzip ccache
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y libgcc-s1:i386

export CCACHE_DIR=${CCACHE_DIR:-$SCRIPT_DIR/.ccache}
export CCACHE_BASEDIR="$SCRIPT_DIR"
export CCACHE_COMPILERCHECK=content
export CCACHE_COMPRESS=true
export CCACHE_COMPRESSLEVEL=3
export CCACHE_DEPEND=true
export CCACHE_MAXSIZE=9G
export CCACHE_SLOPPINESS=time_macros,modules
mkdir -p "$CCACHE_DIR"
ccache --zero-stats
ccache --show-config

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$SCRIPT_DIR/depot_tools:$PATH"

mkdir -p chromium/src/out/X64
cd chromium/src
git init
git config user.name "Titanium x86_64 Actions"
git config user.email "actions@users.noreply.github.com"
git remote add origin "$CHROMIUM_SOURCE"
git fetch --depth 1 "$CHROMIUM_SOURCE" "+refs/tags/$VERSION:chromium_$VERSION"
git checkout --detach "$VERSION"
cp "$SCRIPT_DIR/.gclient" ../.gclient

# Apply the same Vanadium/Titanium patch set as the upstream release build.
rm -rf "$SCRIPT_DIR"/vanadium/patches/*trichrome-{apk-build-targets,browser-apk-targets}.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*{detailed,supported}-language*.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*component-updates.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*{pdf,PDF,for-content-public,toolbar-button,configs-from-config-app}*.patch
replace "$SCRIPT_DIR/vanadium/patches" "VANADIUM" "TITANIUM"
replace "$SCRIPT_DIR/vanadium/patches" "Vanadium" "Titanium"
replace "$SCRIPT_DIR/vanadium/patches" "vanadium" "titanium"
git am --whitespace=nowarn --keep-non-patch "$SCRIPT_DIR"/vanadium/patches/*.patch

gclient sync -D --no-history --nohooks
gclient runhooks
./build/install-build-deps.sh --no-prompt

source "$SCRIPT_DIR/patch.sh"
cp "$SCRIPT_DIR/args-x86_64.gn" out/X64/args.gn
gn gen out/X64
mkdir -p out/tmp out/release

build_status=0
if [[ -n "${TITANIUM_BUILD_TIME_LIMIT:-}" ]]; then
  set +e
  timeout --signal=TERM --kill-after=120s "$TITANIUM_BUILD_TIME_LIMIT" \
    autoninja -C out/X64 -j "$TITANIUM_BUILD_JOBS" chrome_public_apk
  build_status=$?
  set -e
else
  autoninja -C out/X64 -j "$TITANIUM_BUILD_JOBS" chrome_public_apk
fi

ccache --cleanup
ccache --show-stats
du -sh "$CCACHE_DIR"

if (( build_status == 124 )) && [[ "${TITANIUM_ALLOW_INCOMPLETE_BUILD:-0}" == 1 ]]; then
  echo "Stage ${TITANIUM_STAGE_NAME:-warmup} reached its planned time limit; saving the compiler cache checkpoint."
  exit 0
fi
if (( build_status != 0 )); then
  echo "Chromium build exited with status $build_status" >&2
  exit "$build_status"
fi
if [[ "${TITANIUM_ALLOW_INCOMPLETE_BUILD:-0}" == 1 ]]; then
  echo "Stage ${TITANIUM_STAGE_NAME:-warmup} completed the target early; signing the APK now."
fi

unsigned_apk=$(find out/X64/apks -maxdepth 1 -name 'Chrome*.apk' -print -quit)
if [[ -z "$unsigned_apk" ]]; then
  echo "chrome_public_apk did not produce an APK" >&2
  exit 3
fi

unsigned_output="out/tmp/$VERSION-x86_64-unsigned.apk"
signed_output="out/release/$VERSION-x86_64.apk"
mv "$unsigned_apk" "$unsigned_output"

export PATH="$PWD/third_party/jdk/current/bin/:$PATH"
export ANDROID_HOME="$PWD/third_party/android_sdk/public"
sign_apk "$unsigned_output" "$signed_output"

if ! unzip -l "$signed_output" | grep -q 'lib/x86_64/'; then
  echo "Signed APK does not contain x86_64 native libraries" >&2
  exit 4
fi
if unzip -l "$signed_output" | grep -Eq 'lib/(arm64-v8a|armeabi-v7a)/'; then
  echo "Signed APK unexpectedly contains ARM native libraries" >&2
  exit 5
fi

sha256sum "$signed_output" | tee "$signed_output.sha256"
df -hT "$SCRIPT_DIR"
