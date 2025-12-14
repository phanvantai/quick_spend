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

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Move to the iOS directory
cd ios

# Clean any existing pods to start fresh
echo "🧹 Cleaning existing CocoaPods installation..."
rm -rf Podfile.lock Pods/ .symlinks/

# Return to project root for Flutter build
cd $CI_PRIMARY_REPOSITORY_PATH

# Clean Flutter build to avoid improperly formatted define flags
flutter clean

# Build Flutter framework to generate proper xcconfig files and install pods
# Disable tree-shake-icons to avoid IconData non-const issues
echo "🔨 Building Flutter framework with CocoaPods..."
flutter build ios --release --no-codesign --no-tree-shake-icons

# Verify pods are properly installed
cd ios
if [ ! -d "Pods" ]; then
    echo "⚠️ Pods directory not found after Flutter build. Running pod install manually..."
    pod install --repo-update
fi

# Ensure Flutter framework is properly linked
ls -la Flutter/
echo "✅ CocoaPods setup complete"

exit 0