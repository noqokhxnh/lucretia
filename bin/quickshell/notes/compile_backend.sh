#!/bin/bash
g++ -O3 -std=c++17 ../../../src/notes/notes_backend.cpp -o notes_backend
if [ $? -eq 0 ]; then
    echo "Compilation successful: notes_backend"
else
    echo "Compilation failed"
    exit 1
fi
