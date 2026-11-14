#!/bin/bash

# Create complete automated package for Kios
set -e

echo "=== Creating Complete Automated Package ==="

# Create package directory
mkdir -p /tmp/kios-auto-package
cd /tmp/kios-auto-package

# Copy all necessary files
cp -r "/home/tejas/Projects/Tejaskhanna989 aOS/kios"/* .

# Create auto-installer
cat > AUTO_INSTALL_IOS.sh << 'EOF'
#!/bin/bash

# Complete automated iOS 12 installation
set -e

echo "=== Automated iOS 12 Installation ==="

# Check if device is connected
if ! adb devices | grep -q "device"; then
    echo "❌ Connect your device via USB!"
    exit 1
fi

# Download and install Termux
echo "Installing Termux..."
adb shell am start -n com.android.packageinstaller/.PackageInstallerActivity -d 'market://details?id=com.termux' || true
echo "Please install Termux from Play Store, then press Enter..."
read -p ""

# Install required packages
adb shell input text "pkg update && pkg install clang git make python libslirp pixman"
adb shell input tap 500 1400
sleep 10

# Build QEMU
adb shell input text "git clone https://github.com/tejaskhanna989/qemu-sptm.git"
adb shell input tap 500 1400
sleep 5
adb shell input text "cd qemu-sptm && git checkout asoft-android"
adb shell input tap 500 1400
sleep 3
adb shell input text "./configure --target-list=aarch64-softmmu --disable-system --enable-user --disable-capstone --disable-slirp"
adb shell input tap 500 1400
sleep 3
adb shell input text "make -j\$(nproc)"
adb shell input tap 500 1400
sleep 30

# Copy libraries and install
adb shell input text "./pull-libs.sh /data/data/com.termux/files/home/qemu-sptm/qemu-system-aarch64"
adb shell input tap 500 1400
sleep 10

echo "✅ Installation complete! iOS 12 is ready!"
EOF

# Create auto-cleaner
cat > AUTO_CLEAN_ALL.sh << 'EOF'
#!/bin/bash

# Complete automated cleanup
set -e

echo "=== Complete Cleanup ==="

# Uninstall apps
adb shell am force-stop com.kios.ios
adb shell pm uninstall com.kios.ios
adb shell am force-stop com.termux
adb shell pm uninstall com.termux

# Remove files
adb shell rm -rf /data/data/com.termux/files/home/qemu-sptm
adb shell rm -rf /data/local/tmp/kios-fix
adb shell rm -rf /sdcard/Download/kios

echo "✅ Cleanup complete!"
EOF

# Create package
zip -r kios-auto-complete.zip .
mv kios-auto-complete.zip "/home/tejas/Projects/Tejaskhanna989 aOS/kios/"

echo "✅ Complete package created: kios-auto-complete.zip"
echo ""
echo "To use:"
echo "1. Unzip kios-auto-complete.zip"
echo "2. Run ./AUTO_INSTALL_IOS.sh"
echo "3. Follow on-screen instructions"
echo ""
echo "To cleanup: ./AUTO_CLEAN_ALL.sh"