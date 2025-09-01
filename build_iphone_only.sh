#\!/bin/bash

echo "Building iPhone app only (skipping Watch app)..."

# Build just the iPhone target with minimal settings
xcodebuild \
  -project SecureHeart.xcodeproj \
  -target "Secure Heart" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro,arch=arm64" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  -quiet \
  build

echo "iPhone build completed."
