# Kios App Testing Guide

## Overview
This guide provides step-by-step instructions for testing the Kios app with iOS 12 support on your Android device.

## Prerequisites
1. Android device with USB debugging enabled
2. ADB (Android Debug Bridge) installed on your computer
3. USB cable to connect the device

## Quick Start
1. Connect your Android device via USB
2. Enable USB debugging in Developer options
3. Install the APK: `adb install -r kios-test-fixed.apk`
4. Open the Kios app and test iOS 12 installation

## Detailed Testing Steps

### Step 1: Connect Your Device
1. Enable Developer options on your Android device:
   - Go to Settings → About phone
   - Tap "Build number" 7 times to enable Developer options
   - Go back to Settings → System → Developer options
   - Enable "USB debugging"

2. Connect your device to the computer via USB

3. Verify the connection:
   ```bash
   adb devices
   ```
   You should see your device listed

### Step 2: Install the Kios App
1. Navigate to the kios directory:
   ```bash
   cd "/home/tejas/Projects/Tejaskhanna989 aOS/kios"
   ```

2. Install the test APK:
   ```bash
   adb install -r kios-test-fixed.apk
   ```

3. Open the Kios app on your device

### Step 3: Test iOS 12 Installation
1. In the Kios app, tap "Install iOS"
2. The app should start downloading iOS 12.4.1 for iPhone 8
3. After download, it should begin the installation process
4. You should see the iOS boot screen
5. The app should reach the iOS lock screen

### Step 4: Verify Functionality
1. Check that the app doesn't crash when clicking buttons
2. Verify that iOS 12 is being used (not iOS 16)
3. Test the keyboard functionality
4. Check that the app runs without the "Render.alive" error

## Expected Behavior
- App should install successfully without crashes
- "Install iOS" button should work without errors
- iOS 12.4.1 should download and install properly
- App should reach the iOS lock screen
- No "UnsatisfiedLinkError" should occur

## Troubleshooting

### If the app crashes on install:
1. Uninstall the app first: `adb uninstall com.kios.ios`
2. Reinstall: `adb install -r kios-test-fixed.apk`
3. Check device logs: `adb logcat | grep -i kios`

### If you get "Render.alive" error:
This should be fixed in the current APK. If it still occurs:
1. Check the APK verification: `./VERIFY_TEST_APK.sh`
2. Try a different APK from the directory

### If iOS download fails:
1. Check your internet connection on the device
2. Verify that the iOS 12 IPSW URL is accessible
3. Check device storage space

## APK Files Available
- `kios-test-fixed.apk` - Latest test APK with all fixes
- `kios-proper-fixed.apk` - Previous version
- `kios-final-working.apk` - Another working version

## Manual Testing Checklist
- [ ] App installs successfully
- [ ] App opens without crashing
- [ ] "Install iOS" button works
- [ ] iOS 12 downloads correctly
- [ ] Installation process completes
- [ ] iOS boot screen appears
- [ ] Lock screen is reached
- [ ] No crash logs in device logcat
- [ ] Keyboard functionality works
- [ ] App can be closed properly

## Advanced Testing
If you want to test with real QEMU libraries:
1. Install Termux on your device
2. Build QEMU in Termux
3. Use `pull-libs.sh` to copy libraries to the APK

## Support
If you encounter issues:
1. Check the troubleshooting steps above
2. Review the device logs with `adb logcat`
3. Try different APK versions from the directory
4. Ensure you have enough storage space on your device