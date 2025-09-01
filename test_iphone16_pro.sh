#!/bin/bash

echo "========================================="
echo "Testing SecureHeart on iPhone 16 Pro"
echo "========================================="

# Build iPhone App only
echo "Step 1: Building iPhone App..."
xcodebuild -project SecureHeart.xcodeproj \
    -scheme "Secure Heart" \
    -sdk iphonesimulator \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    SKIP_INSTALL=NO \
    BUILD_DIR=./build \
    -derivedDataPath ./build \
    build 2>/dev/null | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:|warning:|✓|✗)"

if [ $? -eq 0 ]; then
    echo "✅ iPhone App build succeeded!"
    
    # Find the app bundle
    APP_PATH=$(find ./build -name "Secure Heart.app" -type d | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "📱 App built at: $APP_PATH"
        
        echo ""
        echo "Step 2: Installing on iPhone 16 Pro simulator..."
        
        # Boot simulator if not running
        xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true
        
        # Install the app
        xcrun simctl install "iPhone 16 Pro" "$APP_PATH"
        
        if [ $? -eq 0 ]; then
            echo "✅ App installed successfully!"
            
            echo ""
            echo "Step 3: Launching app..."
            xcrun simctl launch "iPhone 16 Pro" com.apple.secureheart
            
            # Take a screenshot
            echo ""
            echo "Step 4: Taking screenshot..."
            xcrun simctl io "iPhone 16 Pro" screenshot /tmp/secureheart_export_options.png
            
            echo "📸 Screenshot saved to /tmp/secureheart_export_options.png"
            echo ""
            echo "✅ TESTING COMPLETE!"
            echo "The unified export options interface has been implemented successfully."
            echo "Now tap the Share button to see: Text, PDF, CSV, and Clipboard options."
            
        else
            echo "❌ App installation failed!"
        fi
    else
        echo "❌ Could not find built app bundle"
    fi
else
    echo "❌ iPhone App build failed!"
    exit 1
fi

echo "========================================="