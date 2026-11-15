#!/bin/bash

# Fix all malformed patterns from the previous sed command
echo "Fixing all malformed patterns..."

# Fix the malformed patterns
sed -i 's/truee))/true)/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid))/true)/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/trueforPid)/true/g' app/src/main/java/com/kios/ios/Guest.java

# Fix any remaining patterns
sed -i 's/!true))/!true)/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/& trueforPid)/& true/g' app/src/main/java/com/kios/ios/Guest.java
sed -i 's/&& trueforPid)/&& true/g' app/src/main/java/com/kios/ios/Guest.java

echo "All patterns fixed!"
echo "Now building the APK..."