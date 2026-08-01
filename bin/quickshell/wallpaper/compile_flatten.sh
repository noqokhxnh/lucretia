#!/usr/bin/env bash
# Compile the Matugen color-flatten helper (C++ replacement for the inline
# Python snippet in matugen_reload.sh). Output: ./flatten_colors

set -e
cd "$(dirname "$(realpath "$0")")"

g++ -O3 -march=native -flto -std=c++20 \
    ../../../src/wallpaper/flatten_colors.cpp \
    -o flatten_colors

echo "Compiled flatten_colors -> $(pwd)/flatten_colors"
