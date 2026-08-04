#!/bin/bash

# Build qs_daemon using CMake
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../../src" && pwd)"

echo "Building qs_daemon via CMake..."
cmake -B "$SRC_DIR/build" -S "$SRC_DIR"
if [ $? -ne 0 ]; then
    echo "Error: CMake configuration failed."
    exit 1
fi

cmake --build "$SRC_DIR/build"
if [ $? -eq 0 ]; then
    echo "Compilation successful: qs_daemon"
else
    echo "Compilation failed."
    exit 1
fi
