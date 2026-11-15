# Appetize.io Testing Plan for KiOS App

## Overview
This document outlines the testing plan for the KiOS app using Appetize.io as the Android testing environment.

## Background
The KiOS app has been experiencing crashes due to a `Render.alive()` issue in the `Guest.running()` method. The fix has been implemented in the source code, but we need to verify it works in a real Android environment.

## Current Status
- ✅ Source code fixed: `Guest.running()` now checks PID > 0 instead of calling `Render.alive()`
- ✅ Native libraries: `librender.so`, `libgpucheck.so`, `libunpack.so` included
- ✅ APK created: `kios-minimal-test.apk` with test implementation
- ❌ CI builds failing: Need to fix gradle compatibility issues
- ❌ Physical device disconnected: Using Appetize.io for testing

## Testing APK Details
- **File**: `kios-minimal-test.apk`
- **Package**: `com.kios.ios`
- **Target ABI**: arm64-v8a
- **Android Version**: 10.0+ (Appetize supports up to 16.0)
- **Size**: ~105KB (minimal test version)

## Test Implementation
The test APK includes:
1. **MainActivity**: Tests both `Guest.running()` and `Render.alive()`
2. **Guest class**: Fixed implementation that checks PID > 0
3. **Render class**: Native library wrapper (will likely fail without proper native implementation)
4. **Dummy native library**: `librender.so` (100KB dummy file)

## Expected Results
### Test Scenarios
1. **App Start**: App should launch without crashing
2. **Guest.running()**: Should return `false` (no PID set)
3. **Render.alive()**: May fail with native library error
4. **App Continuation**: App should continue running despite `Render.alive()` error

### Success Criteria
- ✅ App starts without crashing
- ✅ `Guest.running()` works correctly
- ✅ App handles `Render.alive()` errors gracefully
- ✅ No FATAL EXCEPTION related to `Render.alive`

## Testing Steps

### 1. Appetize.io Setup
1. Go to https://appetize.io/
2. Create an account (if needed)
3. Navigate to the "Apps" section
4. Click "Upload App"

### 2. APK Upload
1. Select `kios-minimal-test.apk`
2. Wait for upload to complete
3. Note the public URL for testing

### 3. App Testing
1. Launch the app in the browser
2. Observe the startup behavior
3. Check for any crashes or errors
4. Take screenshots of the output

### 4. Log Analysis
1. Check the browser console for any errors
2. Look for logcat output if available
3. Document any crash reports or exceptions

### 5. Verification
1. Confirm `Guest.running()` returns `false`
2. Check if `Render.alive()` fails with expected error
3. Verify the app continues running despite errors
4. Document the complete behavior

## Potential Issues and Solutions

### Issue 1: Native Library Loading
**Problem**: `Render.alive()` may fail due to dummy native library
**Expected**: Error message but app continues running
**Solution**: This is expected behavior

### Issue 2: Appetize.io Limitations
**Problem**: Appetize may not support all native library features
**Expected**: Some native functionality may not work
**Solution**: Test basic app functionality first

### Issue 3: APK Structure
**Problem**: Test APK is minimal, may not represent full app
**Expected**: Limited functionality but demonstrates the fix
**Solution**: If fix works, apply to full app

## Next Steps After Testing

### If Test Passes
1. Apply the fix to the main app source code
2. Fix the CI build process
3. Create a full APK with the fix
4. Test the full app on Appetize.io

### If Test Fails
1. Analyze the failure logs
2. Refine the fix implementation
3. Create additional test APKs
4. Repeat testing until fix works

## Documentation Requirements
- Screenshots of app behavior
- Console/log output
- Error messages (if any)
- Success/failure criteria met
- Recommendations for next steps

## Timeline
- **Setup**: 15 minutes
- **Upload & Initial Test**: 10 minutes
- **Analysis**: 20 minutes
- **Documentation**: 15 minutes
- **Total**: ~1 hour

## Files Created
- `kios-minimal-test.apk`: Test APK with fix
- `APPETIZE_TESTING_PLAN.md`: This documentation
- `CREATE_MINIMAL_TEST_APK.sh`: Script to recreate the test APK

## Conclusion
This testing plan will verify that the `Render.alive()` fix works correctly in an Android environment. The test APK is designed to demonstrate the fix without requiring the full app functionality. If successful, the fix can be applied to the main app and the CI build process can be fixed.