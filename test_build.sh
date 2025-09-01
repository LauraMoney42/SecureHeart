#!/bin/bash

echo "Testing Secure Heart build..."
cd /Users/lauramoney/Documents/GIT/SecureHeart

# Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -project SecureHeart.xcodeproj -alltargets 2>/dev/null

# Build Watch App
echo "Building Secure Heart Watch App..."
xcodebuild -project SecureHeart.xcodeproj \
    -scheme "Secure Heart Watch App" \
    -sdk watchsimulator \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | head -20

# Build iOS App
echo "Building Secure Heart iOS App..."
xcodebuild -project SecureHeart.xcodeproj \
    -scheme "Secure Heart" \
    -sdk iphonesimulator \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | head -20

echo "Build test complete."