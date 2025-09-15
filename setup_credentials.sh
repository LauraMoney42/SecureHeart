#!/bin/bash

# SecureHeart Credential Setup Script
# This script helps set up Firebase credentials securely

echo "=================================="
echo "SecureHeart Credential Setup"
echo "=================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if template files exist
TEMPLATE_IPHONE="SecureHeart/GoogleService-Info-Template.plist"
TEMPLATE_WATCH="SecureHeart Watch App/GoogleService-Info-Template.plist"

if [ ! -f "$TEMPLATE_IPHONE" ]; then
    echo -e "${RED}Error: iPhone template file not found at $TEMPLATE_IPHONE${NC}"
    exit 1
fi

# Function to setup credentials for a target
setup_target() {
    local template_file=$1
    local target_file=$2
    local target_name=$3

    echo -e "${YELLOW}Setting up $target_name...${NC}"

    # Check if target file already exists
    if [ -f "$target_file" ]; then
        echo -e "${YELLOW}Warning: $target_file already exists${NC}"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping $target_name setup"
            return
        fi
    fi

    # Copy template to target
    cp "$template_file" "$target_file"

    echo -e "${GREEN}✓ Created $target_file from template${NC}"
    echo "Please edit this file and add your Firebase credentials:"
    echo "  - API_KEY"
    echo "  - CLIENT_ID"
    echo "  - GCM_SENDER_ID"
    echo "  - PROJECT_ID"
    echo "  - STORAGE_BUCKET"
    echo "  - GOOGLE_APP_ID"
    echo ""
}

# Setup iPhone app credentials
setup_target "$TEMPLATE_IPHONE" "SecureHeart/GoogleService-Info.plist" "iPhone App"

# Setup Watch app credentials if template exists
if [ -f "$TEMPLATE_WATCH" ]; then
    setup_target "$TEMPLATE_WATCH" "SecureHeart Watch App/GoogleService-Info.plist" "Watch App"
else
    # Create Watch template from iPhone template
    echo -e "${YELLOW}Creating Watch App template...${NC}"
    cp "$TEMPLATE_IPHONE" "$TEMPLATE_WATCH"
    setup_target "$TEMPLATE_WATCH" "SecureHeart Watch App/GoogleService-Info.plist" "Watch App"
fi

# Verify .gitignore
echo -e "${YELLOW}Verifying .gitignore...${NC}"
if [ -f ".gitignore" ]; then
    if grep -q "GoogleService-Info.plist" .gitignore; then
        echo -e "${GREEN}✓ .gitignore is properly configured${NC}"
    else
        echo -e "${RED}Warning: .gitignore may not be properly configured${NC}"
        echo "Adding GoogleService-Info.plist to .gitignore..."
        echo -e "\n# Firebase credentials\nGoogleService-Info.plist" >> .gitignore
        echo -e "${GREEN}✓ Updated .gitignore${NC}"
    fi
else
    echo -e "${RED}Error: .gitignore not found${NC}"
    exit 1
fi

# Final instructions
echo ""
echo "=================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Edit the GoogleService-Info.plist files with your Firebase credentials"
echo "2. Do NOT commit these files to version control"
echo "3. Run 'git status' to verify the files are ignored"
echo ""
echo -e "${YELLOW}Security Reminder:${NC}"
echo "- Keep your Firebase credentials secure"
echo "- Use different credentials for development and production"
echo "- Rotate API keys regularly"
echo "- Never share credentials in issues or pull requests"
echo ""

# Check git status
echo -e "${YELLOW}Current git status:${NC}"
git status --porcelain | grep GoogleService-Info || echo -e "${GREEN}✓ No GoogleService-Info files staged${NC}"