#!/bin/bash

# Optimization flags for performance
FLAGS="-O3 -march=native -flto"

# Detect Qt6 modules
QT_MODULES="Qt6Core Qt6Network Qt6DBus"
LIBS=$(pkg-config --cflags --libs $QT_MODULES)

if [ $? -ne 0 ]; then
    echo "Error: Qt6 development libraries not found."
    exit 1
fi

# Compile
g++ $FLAGS ../../../src/network/network_backend.cpp -o network_backend $LIBS -fPIC

if [ $? -eq 0 ]; then
    echo "Compilation successful: network_backend"
else
    echo "Compilation failed."
    exit 1
fi
