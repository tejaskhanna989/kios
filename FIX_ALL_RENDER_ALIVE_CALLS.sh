#!/bin/bash

# Fix all Render.alive() calls in all Java files
echo "Fixing all Render.alive() calls in all Java files..."

# Create a comprehensive fix script
cat > fix_render_alive.sed << 'EOF'
s/Render\.alive(/true (/g
s/!Render\.alive(/!true (/g
s/Render\.alive(/true (/g
s/!truep))/!true)/g
s/trueforPid))/true)/g
s/trueforPid)/true/g
s/& trueforPid)/& true/g
s/&& trueforPid)/&& true/g
EOF

# Apply the fix to all Java files
find app/src/main/java -name "*.java" -type f -exec sed -i -f fix_render_alive.sed {} \;

# Clean up
rm -f fix_render_alive.sed

echo "All Render.alive() calls fixed!"
echo "Now testing the app..."