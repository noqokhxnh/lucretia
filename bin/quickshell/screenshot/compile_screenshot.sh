cd "$(dirname "${BASH_SOURCE[0]}")"
 
g++ -O3 -std=c++17 ../../../src/screenshot/screenshot_backend.cpp -o screenshot_backend \
    $(pkg-config --cflags --libs libpng zbar) \
    -lpthread
 
if [ $? -eq 0 ]; then
    echo "OK: screenshot_backend compiled (no Qt needed)"
else
    echo "FAILED"
    exit 1
fi
 