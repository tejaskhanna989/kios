# Kios - iOS 12 Testing Guide for Galaxy M30

## Quick Start

1. **Download and extract iOS 12 IPSW**:
   ```bash
   chmod +x extract-ios12.sh
   ./extract-ios12.sh
   ```

2. **Update setup file with extracted info**:
   ```bash
   ./update-setup-ios12.sh
   git add setup/asoft-setup.json
   git commit -m "Add iOS 12 file information"
   git push
   ```

3. **Build and install APK**:
   ```bash
   ./gradlew assembleDebug
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

4. **Test on your M30**:
   - Open Kios app
   - Tap "Set up" → "iOS 12"
   - Wait for download and setup (may take 30-60 minutes)
   - Tap "Start iOS 12"

## What to Expect

### During Setup
- App will download iOS 12 components from Apple (~3GB total)
- Downloads are chunked and resumeable
- Will show progress in notification bar

### First Boot
- iOS 12 should boot to lock screen
- May take 5-10 minutes on first boot
- Screen should show iOS 12 interface
- Touch should work
- Volume buttons should work

### Common Issues & Fixes

#### 1. Download Fails
- Check internet connection
- Try again - downloads are resumeable
- Check storage space (needs 10GB free temporarily)

#### 2. Setup Fails
- Check if IPSW extraction found correct files
- Look at logs in Developer options
- Try deleting app data and reinstalling

#### 3. iOS Doesn't Boot
- Check if device tree is correct for iPhone 8
- May need iOS 12-specific kernel
- QEMU command line may need adjustment

#### 4. App Crashes
- Check Developer options → Running services
- Look at logcat for error messages
- Force stop and restart app

## Debug Commands

While testing, you can use these ADB commands:

```bash
# Check app logs
adb logcat | grep -i kios

# Monitor memory usage
adb shell dumpsys meminfo com.kios.ios

# Force stop app
adb shell am force-stop com.kios.ios

# Clear app data
adb shell pm clear com.kios.ios

# Check storage
adb shell df -h /data
```

## Expected Performance on M30

- **CPU**: Snapdragon 675 (should run iOS 12, but slower than newer chips)
- **RAM**: 4GB (iOS 12 uses 2GB, Android needs 2GB)
- **Storage**: 64GB+ recommended (iOS 12 needs ~3GB)
- **Display**: 6.4" AMOLED (should work well)

## Troubleshooting Checklist

1. ✅ Have at least 10GB free storage
2. ✅ Stable internet connection
3. ✅ Developer options enabled with USB debugging
4. ✅ App installed from APK (not Play Store)
5. ✅ No other memory-intensive apps running
6. ✅ Battery charging during setup

## Next Steps After Success

1. **Performance testing**: Measure boot time, app responsiveness
2. **Feature testing**: Touch, volume, keyboard, Safari
3. **Storage testing**: Install apps, save states
4. **Battery testing**: Monitor power consumption
5. **Comparison**: Compare with iOS 16 performance

## Reporting Issues

If something doesn't work:
1. Check logs with `adb logcat | grep -i kios`
2. Note exact error messages
3. Take screenshots of error screens
4. Report with detailed steps to reproduce