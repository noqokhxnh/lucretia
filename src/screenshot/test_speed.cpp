#include <Magick++.h>
#include <iostream>

using namespace Magick;

int main(int argc, char* argv[]) {
    InitializeMagick(nullptr);
    if (argc < 3) return 1;
    Image img;
    img.read(argv[1]);
    img.resize(Geometry(img.columns() * 2, img.rows() * 2));
    img.write(argv[2]);
    return 0;
}
