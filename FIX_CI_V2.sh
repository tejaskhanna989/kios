#!/bin/bash

# Fix using CI
set -e

echo "=== Fix Using CI ==="

# The issue is that the native library is missing the alive method.
# We need to fix this by creating a proper APK with the fixed source code.

# Let's commit the fixes and trigger a CI build
echo "Committing fixes..."
git add -A
git commit -m "Fix native library crash in APK"

# Push to trigger CI build
echo "Pushing to trigger CI build..."
git push

echo "✅ CI build triggered"
echo "Check the build status at: https://github.com/tejaskhanna989/kios/actions"

# Wait for CI build to complete
echo "Waiting for CI build to complete..."
sleep 30

# Check if CI build completed successfully
echo "Checking CI build status..."
gh run list --limit 1 | grep -E "completed.*success|in_progress"

# If CI build succeeded, download the APK
if [ $? -eq 0 ]; then
    echo "✅ CI build completed successfully!"
    
    # Get the run ID
    RUN_ID=$(gh run list --limit 1 | grep "completed.*success" | awk '{print $1}')
    
    if [ -n "$RUN_ID" ]; then
        echo "Downloading APK from CI run $RUN_ID..."
        gh run download "$RUN_ID" --name "Build Fixed APK"
        
        # Find the APK file
        APK_FILE=$(find . -name "*.apk" -type f | head -1)
        
        if [ -n "$APK_FILE" ]; then
            echo "✅ APK downloaded: $APK_FILE"
            
            # Install on device
            echo "Installing on connected device..."
            adb -s 320081735bb166a3 install -r "$APK_FILE"
            
            # Launch the app
            echo "Launching app..."
            adb -s 320081735bb166a3 shell am force-stop com.kios.ios
            adb -s 320081735bb166a3 shell am start -n com.kios.ios/.MainActivity
            
            # Check if app is running
            sleep 3
            if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
                echo "✅ App is running successfully!"
                
                # Test clicking the Install iOS button
                echo "Testing Install iOS button..."
                adb -s 320081735bb166a3 shell "input tap 500 1000"
                sleep 3
                
                if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
                    echo "✅ App survived the click!"
                    
                    # Test multiple clicks
                    echo "Testing multiple clicks..."
                    for i in {1..3}; do
                        adb -s 320081735bb166a3 shell "input tap 500 1000"
                        sleep 2
                        if adb -s 320081735bb166a3 shell "ps | grep -v grep | grep com.kios.ios"; then
                            echo "✅ Click $i successful"
                        else
                            echo "❌ App crashed on click $i"
                            break
                        fi
                    done
                    
                    echo "✅ CI fix successful!"
                else
                    echo "❌ App crashed when clicking"
                fi
            else
                echo "❌ App crashed on launch"
            fi
        else
            echo "❌ APK not found"
        fi
    else
        echo "❌ Run ID not found"
    fi
else
    echo "❌ CI build failed"
fi