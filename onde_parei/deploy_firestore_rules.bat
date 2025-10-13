@echo off
echo "Deploying Firestore Security Rules..."
echo.

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if errorlevel 1 (
    echo "Firebase CLI not found. Installing..."
    npm install -g firebase-tools
    if errorlevel 1 (
        echo "Error: Failed to install Firebase CLI."
        echo "Please install it manually: npm install -g firebase-tools"
        pause
        exit /b 1
    )
)

REM Login to Firebase (if not already logged in)
echo "Checking Firebase authentication..."
firebase projects:list >nul 2>&1
if errorlevel 1 (
    echo "Please login to Firebase:"
    firebase login
)

REM Deploy Firestore rules and indexes
echo "Deploying Firestore security rules and indexes..."
firebase deploy --only firestore

if errorlevel 1 (
    echo "Error: Failed to deploy Firestore rules."
    echo "Please try manually:"
    echo "firebase deploy --only firestore:rules"
    pause
    exit /b 1
) else (
    echo "Firestore rules deployed successfully!"
    echo.
    echo "Your app should now work without permission errors."
    pause
)
