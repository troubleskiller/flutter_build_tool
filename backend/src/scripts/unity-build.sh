#!/bin/bash

# Unity Build Script
# This script handles Unity project export to Flutter

set -e

# Arguments
UNITY_EDITOR_PATH="$1"
UNITY_PROJECT_PATH="$2"
BUILD_METHOD="$3"
EXTRA_ARGS="${@:4}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if Unity Editor exists
if [ ! -f "$UNITY_EDITOR_PATH" ]; then
    log_error "Unity Editor not found at: $UNITY_EDITOR_PATH"
    exit 1
fi

# Check if project path exists
if [ ! -d "$UNITY_PROJECT_PATH" ]; then
    log_error "Unity project not found at: $UNITY_PROJECT_PATH"
    exit 1
fi

log_info "Starting Unity build process..."
log_info "Unity Editor: $UNITY_EDITOR_PATH"
log_info "Project Path: $UNITY_PROJECT_PATH"
log_info "Build Method: $BUILD_METHOD"

# Execute Unity build
log_info "Executing Unity build command..."

"$UNITY_EDITOR_PATH" \
    -batchmode \
    -quit \
    -projectPath "$UNITY_PROJECT_PATH" \
    -executeMethod "$BUILD_METHOD" \
    -logFile - \
    $EXTRA_ARGS

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    log_info "Unity build completed successfully!"
else
    log_error "Unity build failed with exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi

# Check if export was successful
EXPORT_PATH="$UNITY_PROJECT_PATH/../flutter_project/unity"
if [ -d "$EXPORT_PATH" ]; then
    log_info "Unity export found at: $EXPORT_PATH"

    # Count exported files
    FILE_COUNT=$(find "$EXPORT_PATH" -type f | wc -l)
    log_info "Exported $FILE_COUNT files to Flutter project"
else
    log_warning "Unity export directory not found. Build may have failed."
fi

log_info "Unity build script completed"
exit 0