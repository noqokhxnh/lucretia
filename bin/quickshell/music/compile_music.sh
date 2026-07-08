#!/bin/bash

# Optimization flags for performance
FLAGS="-O3 -march=native -flto"

# Detect Qt6 modules
QT_MODULES="Qt6Core Qt6Gui Qt6Network Qt6DBus"
LIBS=$(pkg-config --cflags --libs $QT_MODULES)

if [ $? -ne 0 ]; then
    echo "Error: Qt6 development libraries not found."
    exit 1
fi

# Run moc for signals/slots
moc ../../../src/music/music_backend.cpp -o music_backend.moc

# Compile
g++ $FLAGS ../../../src/music/music_backend.cpp -o music_backend $LIBS -fPIC

if [ $? -eq 0 ]; then
    echo "Compilation successful: music_backend"
    rm music_backend.moc
else
    echo "Compilation failed."
    exit 1
fi
