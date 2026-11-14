# Kios App Crash Fix

## Problem
The app crashes immediately on startup with this error:
```
UnsatisfiedLinkError: No implementation found for boolean com.kios.ios.Render.alive(int)
```

## Cause
The APK is missing the native QEMU libraries (`libqemu.so` and `libqemuimg.so`) that are needed to run the iOS emulator.

## Solutions

### Option 1: Build QEMU in Termux (Recommended)
1. **Install Termux** from F-Droid
2. **Install required packages**:
   ```bash
   pkg update
   pkg install clang git make python libslirp pixman
   ```
3. **Clone and build QEMU**:
   ```bash
   git clone https://github.com/tejaskhanna989/qemu-sptm.git
   cd qemu-sptm
   git checkout asoft-android
   ./configure --target-list=aarch64-softmmu --disable-system --enable-user --disable-capstone --disable-slirp
   make -j$(nproc)
   ```
4. **Copy libraries to APK**:
   ```bash
   cd /path/to/kios
   ./pull-libs.sh /data/data/com.termux/files/home/qemu-sptm/qemu-system-aarch64
   ```
5. **Build and install**:
   ```bash
   ./gradlew assembleDebug
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

### Option 2: Quick UI Test (Without QEMU)
For testing the app interface without the emulator:

1. **Create dummy libraries**:
   ```bash
   mkdir -p app/src/main/jniLibs/arm64-v8a
   echo 'dummy lib' > app/src/main/jniLibs/arm64-v8a/libqemu.so
   echo 'dummy lib' > app/src/main/jniLibs/arm64-v8a/libqemuimg.so
   ```

2. **Build and install**:
   ```bash
   ./gradlew assembleDebug
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

3. **Note**: The app will open but iOS won't run. You can test the UI, settings, and other features.

### Option 3: Use Pre-built Libraries
Check if pre-built QEMU libraries are available:
- https://github.com/tejaskhanna989/kios/releases
- Look for `libqemu.so` and `libqemuimg.so` files

## Current Status
- ✅ APK downloads and installs
- ✅ App opens but crashes immediately
- ❌ Missing QEMU native libraries
- 🔄 Need to build or obtain QEMU libraries

## Next Steps
1. Choose one of the options above
2. Follow the instructions
3. Test the app again
4. Report back what works

## Testing After Fix
Once you have the QEMU libraries:
1. Install the fixed APK
2. Open the app
3. Try to set up iOS 12
4. Test if it boots properly

## Contact
If you need help with the fix, check the troubleshooting guide or ask for assistance.