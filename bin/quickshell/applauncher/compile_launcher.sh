#!/bin/bash
g++ -O3 -std=c++17 ../../../src/applauncher/app_fetcher.cpp -o app_fetcher
if [ $? -eq 0 ]; then
    echo "Compilation successful: app_fetcher"
else
    echo "Compilation failed: app_fetcher"
    exit 1
fi

g++ -O3 -std=c++17 ../../../src/applauncher/tools_fetcher.cpp -o tools_fetcher -lcurl
if [ $? -eq 0 ]; then
    echo "Compilation successful: tools_fetcher"
else
    echo "Compilation failed: tools_fetcher"
    exit 1
fi

g++ -O3 -std=c++17 ../../../src/applauncher/app_launcher_backend.cpp -o app_launcher_backend
if [ $? -eq 0 ]; then
    echo "Compilation successful: app_launcher_backend"
else
    echo "Compilation failed: app_launcher_backend"
    exit 1
fi
