#!/bin/bash

# Flutter Build Script
# This script handles Flutter APK building

set -e

# Arguments
FLUTTER_SDK_PATH="$1"
FLUTTER_PROJECT_PATH="$2"
BUILD_TYPE="${3:-release}"  # Default to release
EXTRA_ARGS="${@:4}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if Flutter SDK exists
if [ ! -d "$FLUTTER_SDK_PATH" ]; then
    log_error "Flutter SDK not found at: $FLUTTER_SDK_PATH"
    exit 1
fi

# Check if project path exists
if [ ! -d "$FLUTTER_PROJECT_PATH" ]; then
    log_error "Flutter project not found at: $FLUTTER_PROJECT_PATH"
    exit 1
fi

FLUTTER_BIN="$FLUTTER_SDK_PATH/bin/flutter"

# Check Flutter binary
if [ ! -f "$FLUTTER_BIN" ]; then
    log_error "Flutter binary not found at: $FLUTTER_BIN"
    exit 1
fi

log_info "Starting Flutter build process..."
log_info "Flutter SDK: $FLUTTER_SDK_PATH"
log_info "Project Path: $FLUTTER_PROJECT_PATH"
log_info "Build Type: $BUILD_TYPE"

# Change to project directory
cd "$FLUTTER_PROJECT_PATH"

# Clean previous build
log_step "Cleaning previous build..."
"$FLUTTER_BIN" clean

# Get dependencies
log_step "Getting Flutter dependencies..."
"$FLUTTER_BIN" pub get

# Run code generation if needed
if [ -f "build.yaml" ]; then
    log_step "Running code generation..."
    "$FLUTTER_BIN" pub run build_runner build --delete-conflicting-outputs
fi

# Analyze code (optional, can be skipped for faster builds)
# log_step "Analyzing code..."
# "$FLUTTER_BIN" analyze

# Build APK
log_step "Building APK..."

if [ "$BUILD_TYPE" = "release" ]; then
    "$FLUTTER_BIN" build apk --release $EXTRA_ARGS
elif [ "$BUILD_TYPE" = "debug" ]; then
    "$FLUTTER_BIN" build apk --debug $EXTRA_ARGS
else
    "$FLUTTER_BIN" build apk --profile $EXTRA_ARGS
fi

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    log_info "Flutter build completed successfully!"

    # Find and display APK information
    APK_PATH=""
    if [ "$BUILD_TYPE" = "release" ]; then
        APK_PATH="$FLUTTER_PROJECT_PATH/build/app/outputs/flutter-apk/app-release.apk"
    elif [ "$BUILD_TYPE" = "debug" ]; then
        APK_PATH="$FLUTTER_PROJECT_PATH/build/app/outputs/flutter-apk/app-debug.apk"
    else
        APK_PATH="$FLUTTER_PROJECT_PATH/build/app/outputs/flutter-apk/app-profile.apk"
    fi

    if [ -f "$APK_PATH" ]; then
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        log_info "APK generated at: $APK_PATH"
        log_info "APK size: $APK_SIZE"

        # Get APK details using aapt if available
        if command -v aapt &> /dev/null; then
            log_step "APK details:"
            aapt dump badging "$APK_PATH" | grep -E "package:|application-label:|launchable-activity:" || true
        fi
    else
        log_warning "APK file not found at expected location: $APK_PATH"
    fi
else
    log_error "Flutter build failed with exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

log_info "Flutter build script completed"
exit 0