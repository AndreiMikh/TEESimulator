# shellcheck disable=SC2034
SKIPUNZIP=1
MIN_SDK=29
CONFIG_DIR=/data/adb/tricky_store

# --- Installation Context Check ---
if [ "$BOOTMODE" != true ]; then
  ui_print "Install in Root Manager"
  abort "⚠️ Custom Recovery Installation is Not Supported"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "🚩 Update Root Manager"
fi

# --- Version Info ---
VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "🚀 Installing TEE Simulator $VERSION"
ui_print ""

# --- Architecture Handling ---
case "$ARCH" in
  arm64) ABI_DIR="arm64-v8a" ;;
  arm)   ABI_DIR="armeabi-v7a" ;;
  x64)   ABI_DIR="x86_64" ;;
  x86)   ABI_DIR="x86" ;;
  *)     abort "⚠️ Unsupported Architecture: $ARCH" ;;
esac

ui_print "📌 Device Platform: $ARCH"
ui_print "📌 Using ABI: $ABI_DIR"

# --- SDK Check ---
if [ "$API" -lt "$MIN_SDK" ]; then
  abort "⚠️ Unsupported SDK: $API, Minimum Required is $MIN_SDK"
else
  ui_print "📌 Device SDK: $API"
fi
ui_print ""

# --- Helper to install files ---
install_file() {
  if ! unzip -qqjo "$ZIPFILE" "$1" -d "$2"; then
    abort "⚠️ Failed to Extract $1"
  fi
  ui_print "✔️ Extracted $1"
}

# --- Installation ---
ui_print "🚀 Extracting Module Files"
for file in customize.sh module.prop service.sh sepolicy.rule daemon; do
  install_file "$file" "$MODPATH"
done

# Handle service.apk or classes.dex
if unzip -l "$ZIPFILE" | grep -q "service.apk"; then
  install_file "service.apk" "$MODPATH"
elif unzip -l "$ZIPFILE" | grep -q "classes.dex"; then
  install_file "classes.dex" "$MODPATH"
else
  abort "⚠️ Neither Service APK nor Classes DEX Found"
fi

chmod 755 "$MODPATH/daemon"
ui_print ""

ui_print "📌 Extracting $ARCH Libraries"
install_file "lib/$ABI_DIR/libTEESimulator.so" "$MODPATH"
install_file "lib/$ABI_DIR/libinject.so" "$MODPATH"
ui_print ""

mv "$MODPATH/libinject.so" "$MODPATH/inject"
chmod 755 "$MODPATH/inject"

# --- Configuration Files ---
if [ ! -d "$CONFIG_DIR" ]; then
  ui_print "✔️ Creating Configuration Directory"
  mkdir -p "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/keybox.xml" ]; then
  ui_print "🚀 Adding AOSP Software Keybox"
  install_file "keybox.xml" "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/target.txt" ]; then
  ui_print "🚀 Adding Default Target Scope"
  install_file "target.txt" "$CONFIG_DIR"
fi
