#!/bin/sh

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# set unlimited open files limit
ulimit -n 4096

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Checkout a specific version 3.38.0
cd $HOME/flutter
git fetch --tags
git checkout 3.38.0

# Return to project root
cd $CI_PRIMARY_REPOSITORY_PATH

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

# Install Flutter dependencies.
flutter pub get

# Clean Flutter build to avoid improperly formatted define flags
flutter clean

# Build Flutter framework to generate proper xcconfig files
# Disable tree-shake-icons to avoid IconData non-const issues
flutter build ios --release --no-codesign --no-tree-shake-icons

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Move to the iOS directory
cd ios

# Ensure CocoaPods is using the latest repo updates
pod repo update

# Try pod install first, if it fails, reset dependencies and retry
if ! pod install --repo-update; then
    echo "⚠️ Pod install failed. Cleaning dependencies..."
    
    # Remove existing Podfile.lock and cached Pods to avoid conflicts
    pod deintegrate
    rm -rf Podfile.lock Pods/

    # Reinstall dependencies
    pod install
fi

exit 0