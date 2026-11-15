#!/bin/bash

# Fix all remaining Render.alive() calls in Guest.java
echo "Fixing all remaining Render.alive() calls..."

# Fix the remaining malformed replacements
sed -i 's/truep))/true)/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid))/true)/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java

# Replace any remaining patterns
sed -i 's/!true)/!true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/& trueforPid)/& true/g' app/src/main/java/com/kios/ios/Guest.java

echo "Fixes applied!"
echo "Now building the APK..."