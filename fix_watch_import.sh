#!/bin/bash

echo "Fixing WatchKit import issues..."

# Replace WatchKit import with a conditional compilation check
sed -i '' 's/import WatchKit/#if canImport(WatchKit)\nimport WatchKit\n#endif/' "/Users/lauramoney/Documents/GIT/SecureHeart/SecureHeart Watch App/SecureHeartApp.swift"
sed -i '' 's/import WatchKit/#if canImport(WatchKit)\nimport WatchKit\n#endif/' "/Users/lauramoney/Documents/GIT/SecureHeart/SecureHeart Watch App/HeartRateManager.swift"

echo "Done fixing WatchKit imports."