# Quick Testing Guide for Kios on Galaxy M30

## 🚀 Ready to Test!

Everything is prepared for you to test Kios on your M30. Here's your step-by-step guide:

### Step 1: Build the APK
```bash
cd /path/to/kios
./BUILD_SCRIPT.sh
```
This will create the APK at: `app/build/outputs/apk/debug/app-debug.apk`

### Step 2: Install on Your M30
```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Step 3: Prepare iOS 12 Files
```bash
./extract-ios12.sh
```
This downloads and extracts the iOS 12 IPSW for iPhone 8.

### Step 4: Update Configuration
```bash
./update-setup-ios12.sh
git add setup/asoft-setup.json
git commit -m "Add iPhone 8 iOS 12 file information"
git push
```

### Step 5: Build and Install Updated APK
```bash
./BUILD_SCRIPT.sh
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Step 6: Test on Your M30
1. Open Kios app
2. Tap "Set up" → "iOS 12"
3. Wait for download and setup (30-60 minutes)
4. Tap "Start iOS 12"
5. See if it boots to the lock screen!

## 📱 What to Expect

### Working Features:
- ✅ iOS 12 interface
- ✅ Touch controls
- ✅ Volume buttons
- ✅ On-screen keyboard
- ✅ Side bar with Home/Power controls

### Performance on M30:
- CPU: Snapdragon 675 (should work, but slower than newer chips)
- RAM: 4GB (iOS 12 uses 2GB, Android needs 2GB)
- Storage: Needs ~3GB for iOS 12

## 🔍 Monitor While Testing

Open these terminals while testing:

```bash
# Monitor app logs
adb logcat | grep -i kios

# Check memory usage
adb shell dumpsys meminfo com.kios.ios

# Force stop if needed
adb shell am force-stop com.kios.ios
```

## ❓ What If It Doesn't Work?

If iOS 12 doesn't boot:
1. Check if IPSW extraction found correct files
2. Look at error logs in `adb logcat`
3. Try deleting app data and reinstalling
4. Check if you have enough storage space

## 🎯 Success Criteria

Complete success = iOS 12 boots to lock screen and basic controls work!

## 📞 Need Help?

If you get stuck:
1. Check the detailed guides:
   - `TESTING_GUIDE.md`
   - `M30_TEST_CHECKLIST.md`
2. Monitor the logs with `adb logcat`
3. Note any error messages
4. Report back what worked and what didn't

---

**Good luck with testing! 🍎✨**

Remember: This is experimental software, so don't be discouraged if it doesn't work perfectly on the first try. The goal is to learn what works and what needs improvement.