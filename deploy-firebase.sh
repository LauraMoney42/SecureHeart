#!/bin/bash

# SecureHeart Firebase Deployment Script
# Deploys Cloud Functions, Firestore rules, and configures services

set -e  # Exit on any error

echo "🚀 Starting SecureHeart Firebase Deployment"
echo "Project: heart-577bc"
echo "=================================="

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "🔑 Please log in to Firebase"
    firebase login
fi

# Set project
echo "📋 Setting Firebase project..."
firebase use heart-577bc

# Build and deploy functions
echo "⚙️  Building Cloud Functions..."
cd firebase-functions

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing function dependencies..."
    npm install
fi

# Build TypeScript
echo "🔨 Compiling TypeScript..."
npm run build

# Deploy functions
echo "🚀 Deploying Cloud Functions..."
cd ..
firebase deploy --only functions

# Deploy Firestore rules
echo "🔒 Deploying Firestore security rules..."
firebase deploy --only firestore:rules

# Deploy Firestore indexes
echo "📊 Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

# Configuration check
echo ""
echo "🔧 CONFIGURATION REQUIRED:"
echo "=================================="
echo ""
echo "1. Configure Twilio (SMS):"
echo "   firebase functions:config:set twilio.account_sid=\"YOUR_TWILIO_ACCOUNT_SID\""
echo "   firebase functions:config:set twilio.auth_token=\"YOUR_TWILIO_AUTH_TOKEN\""
echo "   firebase functions:config:set twilio.phone_number=\"YOUR_TWILIO_PHONE_NUMBER\""
echo ""
echo "2. Configure SendGrid (Email):"
echo "   firebase functions:config:set sendgrid.api_key=\"YOUR_SENDGRID_API_KEY\""
echo "   firebase functions:config:set sendgrid.from_email=\"alerts@yourdomain.com\""
echo ""
echo "3. After configuration, redeploy functions:"
echo "   firebase deploy --only functions"
echo ""

# Check current configuration
echo "📋 Current function configuration:"
firebase functions:config:get

echo ""
echo "✅ Firebase deployment completed!"
echo ""
echo "🧪 TESTING CHECKLIST:"
echo "====================="
echo "□ Add emergency contact in iOS app"
echo "□ Verify contact invitation SMS/email sent"
echo "□ Trigger emergency alert"
echo "□ Confirm emergency SMS/email received"
echo "□ Test push notifications"
echo "□ Verify Firestore data structure"
echo ""
echo "📊 Monitor logs with: firebase functions:log"
echo "🔍 View Firebase Console: https://console.firebase.google.com/project/heart-577bc"