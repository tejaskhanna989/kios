# Kios Testing Checklist for Galaxy M30

## Before You Start ✅

### Phone Requirements
- [ ] Galaxy M30 with Android 10 or later
- [ ] At least 10GB free storage
- [ ] Stable Wi-Fi connection
- [ ] Battery charging (recommended)
- [ ] USB debugging enabled in Developer options

### PC Requirements
- [ ] Android SDK installed
- [ ] ADB (Android Debug Bridge) available
- [ ] Git repository cloned
- [ ] At least 5GB free disk space

## Installation Steps 📱

### 1. Build the APK
```bash
cd /path/to/kios
./BUILD_SCRIPT.sh
```

### 2. Install on M30
```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 3. Verify Installation
- [ ] App icon appears on home screen
- [ ] App opens without crashing
- [ ] Check Developer options → Running services

## iOS 12 Setup Steps 🍎

### 1. Extract iOS 12 IPSW
```bash
./extract-ios12.sh
```
This will:
- Download iOS 12.4.1 IPSW (~3GB)
- Extract contents
- Show you the key files

### 2. Update Setup Configuration
```bash
./update-setup-ios12.sh
```
This will:
- Update setup/asoft-setup.json with real file paths
- Calculate CRC-32 values
- Prepare for iOS 12 installation

### 3. Commit Changes
```bash
git add setup/asoft-setup.json
git commit -m "Add iPhone 8 iOS 12 file information"
git push
```

### 4. Build and Install Updated APK
```bash
./BUILD_SCRIPT.sh
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Testing iOS 12 🧪

### 1. First Launch
- [ ] Open Kios app
- [ ] Tap "Set up" → "iOS 12"
- [ ] Wait for download to start
- [ ] Monitor progress in notification bar

### 2. Download Phase
- [ ] Downloads are chunked (resumable)
- [ ] Progress shows percentage and remaining time
- [ ] Can pause/resume downloads
- [ ] Handles network interruptions

### 3. Setup Phase
- [ ] Downloads complete (~3GB total)
- [ ] Helper VM starts building iOS disk
- [ ] Shows "Building iOS disk..." progress
- [ ] May take 30-60 minutes

### 4. First Boot
- [ ] iOS 12 starts booting
- [ ] Shows Apple logo
- [ ] Progress indicator
- [ ] Should reach lock screen in 5-10 minutes

## Expected Results ✅

### Working Features
- [ ] iOS 12 interface appears
- [ ] Touch screen works
- [ ] Volume buttons work
- [ ] On-screen keyboard appears
- [ ] Home button in side bar works
- [ ] Power button in side bar works
- [ ] Screen rotation works

### Performance Tests
- [ ] Boot time < 10 minutes
- [ ] Touch response < 100ms
- [ ] No crashes during use
- [ ] Memory usage reasonable

## Troubleshooting ❌

### Common Issues
1. **Download fails**
   - Check internet connection
   - Try again (resumable)
   - Clear app data and retry

2. **Setup fails**
   - Verify IPSW files correct
   - Check storage space
   - Look at logs: `adb logcat | grep -i kios`

3. **iOS doesn't boot**
   - Check device tree filename
   - Verify kernel compatibility
   - Check QEMU command line

4. **App crashes**
   - Force stop app
   - Clear cache and data
   - Check error logs

## Log Monitoring 🔍

While testing, monitor these logs:
```bash
# General logs
adb logcat | grep -i kios

# Memory usage
adb shell dumpsys meminfo com.kios.ios

# CPU usage
adb shell top | grep kios

# Storage
adb shell df -h /data
```

## Report Results 📊

After testing, report:
1. What worked ✅
2. What didn't work ❌
3. Error messages
4. Performance metrics
5. Screenshots of issues

## Success Criteria 🎯

Complete success means:
- iOS 12 boots to lock screen
- Touch controls work
- Basic apps (Safari) functional
- No crashes during use
- Reasonable performance on M30