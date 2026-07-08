#!/bin/bash

# Optimization flags for performance
FLAGS="-O3 -march=native -flto -std=c++20 -pthread"

# Detect Qt6 modules
QT_MODULES="Qt6Core Qt6Network Qt6DBus Qt6Gui"
LIBS=$(pkg-config --cflags --libs $QT_MODULES)

if [ $? -ne 0 ]; then
    echo "Error: Qt6 development libraries not found."
    exit 1
fi

# Additional dependencies
DEPS="-lsqlite3 -lzbar"

echo "Generating MOC file..."
# Try to find moc for Qt6 (could be moc, moc-qt6, or inside qt6/bin)
MOC_BIN="moc"
if command -v moc-qt6 &> /dev/null; then
    MOC_BIN="moc-qt6"
elif [ -f "/usr/lib/qt6/moc" ]; then
    MOC_BIN="/usr/lib/qt6/moc"
elif [ -f "/usr/lib/qt6/bin/moc" ]; then
    MOC_BIN="/usr/lib/qt6/bin/moc"
elif [ -f "/usr/lib64/qt6/bin/moc" ]; then
    MOC_BIN="/usr/lib64/qt6/bin/moc"
fi

$MOC_BIN ../../src/qs_daemon.cpp -o ../../src/qs_daemon.moc
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate MOC file."
    exit 1
fi

echo "Compiling qs_daemon.cpp..."

# Compile
g++ $FLAGS ../../src/qs_daemon.cpp -o qs_daemon $LIBS $DEPS -fPIC

if [ $? -eq 0 ]; then
    echo "Compilation successful: qs_daemon"
else
    echo "Compilation failed."
    exit 1
fi
