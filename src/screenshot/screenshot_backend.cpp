/*
 * screenshot_backend.cpp
 * Beautify: libpng thuần — không cần Qt platform plugin, khởi động <100ms
 * Scan QR:  zbar (giữ nguyên logic cũ)
 *
 * Build:
 *   g++ -O3 -std=c++17 screenshot_backend.cpp -o screenshot_backend \
 *       $(pkg-config --cflags --libs libpng zbar) \
 *       -lpthread
 *
 * Usage:
 *   ./screenshot_backend beautify <input.png> <output.png>
 *   ./screenshot_backend scan     <input.png>
 */

#include <png.h>
#include <zbar.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <iostream>
#include <vector>
#include <climits>
#include <algorithm>

// ─────────────────────────────────────────────────────────────────────────────
// Kiểu ảnh đơn giản (RGBA 8-bit per channel)
// ─────────────────────────────────────────────────────────────────────────────

struct Image {
    int w = 0, h = 0;
    std::vector<uint8_t> px; // RGBA, row-major

    bool ok() const { return w > 0 && h > 0 && (int)px.size() == w * h * 4; }

    uint8_t* row(int y) { return px.data() + y * w * 4; }
    const uint8_t* row(int y) const { return px.data() + y * w * 4; }

    // pixel tại (x,y) — trả về pointer RGBA[4]
    uint8_t* at(int x, int y) { return row(y) + x * 4; }
    const uint8_t* at(int x, int y) const { return row(y) + x * 4; }
};

// ─────────────────────────────────────────────────────────────────────────────
// PNG I/O
// ─────────────────────────────────────────────────────────────────────────────

static Image load_png(const char* path) {
    Image img;
    FILE* fp = fopen(path, "rb");
    if (!fp) { std::cerr << "Cannot open: " << path << '\n'; return img; }

    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
    png_infop info  = png_create_info_struct(png);
    if (setjmp(png_jmpbuf(png))) {
        png_destroy_read_struct(&png, &info, nullptr);
        fclose(fp);
        return img;
    }

    png_init_io(png, fp);
    png_read_info(png, info);

    int w  = png_get_image_width(png, info);
    int h  = png_get_image_height(png, info);
    png_byte color_type = png_get_color_type(png, info);
    png_byte bit_depth  = png_get_bit_depth(png, info);

    // Normalize thành RGBA 8-bit
    if (bit_depth == 16) png_set_strip_16(png);
    if (color_type == PNG_COLOR_TYPE_PALETTE) png_set_palette_to_rgb(png);
    if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8) png_set_expand_gray_1_2_4_to_8(png);
    if (png_get_valid(png, info, PNG_INFO_tRNS)) png_set_tRNS_to_alpha(png);
    if (color_type == PNG_COLOR_TYPE_RGB ||
        color_type == PNG_COLOR_TYPE_GRAY ||
        color_type == PNG_COLOR_TYPE_PALETTE) png_set_filler(png, 0xFF, PNG_FILLER_AFTER);
    if (color_type == PNG_COLOR_TYPE_GRAY ||
        color_type == PNG_COLOR_TYPE_GRAY_ALPHA) png_set_gray_to_rgb(png);

    png_read_update_info(png, info);

    img.w = w; img.h = h;
    img.px.resize((size_t)w * h * 4);

    std::vector<png_bytep> rows(h);
    for (int y = 0; y < h; ++y) rows[y] = img.px.data() + y * w * 4;
    png_read_image(png, rows.data());

    png_destroy_read_struct(&png, &info, nullptr);
    fclose(fp);
    return img;
}

// Lưu PNG RGB (không alpha) với compression level tùy chọn
static bool save_png_rgb(const char* path, const Image& img, int compress = 1) {
    FILE* fp = fopen(path, "wb");
    if (!fp) { std::cerr << "Cannot write: " << path << '\n'; return false; }

    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
    png_infop info  = png_create_info_struct(png);
    if (setjmp(png_jmpbuf(png))) {
        png_destroy_write_struct(&png, &info);
        fclose(fp);
        return false;
    }

    png_init_io(png, fp);
    png_set_compression_level(png, compress);
    png_set_IHDR(png, info, img.w, img.h, 8,
                 PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png, info);

    // Convert RGBA -> RGB khi write
    std::vector<uint8_t> row_rgb(img.w * 3);
    for (int y = 0; y < img.h; ++y) {
        const uint8_t* src = img.row(y);
        for (int x = 0; x < img.w; ++x) {
            row_rgb[x*3+0] = src[x*4+0];
            row_rgb[x*3+1] = src[x*4+1];
            row_rgb[x*3+2] = src[x*4+2];
        }
        png_write_row(png, row_rgb.data());
    }

    png_write_end(png, nullptr);
    png_destroy_write_struct(&png, &info);
    fclose(fp);
    return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility: blend pixel với alpha premultiplied (source over)
// ─────────────────────────────────────────────────────────────────────────────

static inline void blend_over(uint8_t* dst, uint8_t sr, uint8_t sg, uint8_t sb, uint8_t sa) {
    if (sa == 0) return;
    if (sa == 255) { dst[0]=sr; dst[1]=sg; dst[2]=sb; dst[3]=255; return; }
    int inv = 255 - sa;
    dst[0] = (uint8_t)((sr * sa + dst[0] * inv) / 255);
    dst[1] = (uint8_t)((sg * sa + dst[1] * inv) / 255);
    dst[2] = (uint8_t)((sb * sa + dst[2] * inv) / 255);
    dst[3] = 255;
}

// ─────────────────────────────────────────────────────────────────────────────
// Vẽ filled ellipse lên ảnh RGBA
// ─────────────────────────────────────────────────────────────────────────────

static void draw_ellipse(Image& img, int cx, int cy, int rx, int ry,
                          uint8_t r, uint8_t g, uint8_t b) {
    for (int dy = -ry; dy <= ry; ++dy) {
        for (int dx = -rx; dx <= rx; ++dx) {
            double nx = (double)dx / rx;
            double ny = (double)dy / ry;
            if (nx*nx + ny*ny > 1.0) continue;
            int px = cx + dx, py = cy + dy;
            if (px < 0 || py < 0 || px >= img.w || py >= img.h) continue;
            uint8_t* p = img.at(px, py);
            p[0]=r; p[1]=g; p[2]=b; p[3]=255;
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vẽ rounded-rect mask: set alpha=255 bên trong, 0 bên ngoài
// Dùng SDF (signed distance field) đơn giản
// ─────────────────────────────────────────────────────────────────────────────

static void apply_rounded_mask(Image& img, int radius) {
    int w = img.w, h = img.h;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            // Corner SDF
            int cx = std::max(0, std::max(radius - x - 1, x - (w - radius)));
            int cy = std::max(0, std::max(radius - y - 1, y - (h - radius)));
            if (cx*cx + cy*cy > radius*radius) {
                img.at(x, y)[3] = 0;
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient fill (linear, diagonal)
// ─────────────────────────────────────────────────────────────────────────────

struct Color3 { uint8_t r,g,b; };
struct Color3f { float r,g,b; };

static void fill_gradient(Image& img, Color3 c0, Color3 c1) {
    int w = img.w, h = img.h;
    Color3f f0 = { (float)c0.r, (float)c0.g, (float)c0.b };
    Color3f f1 = { (float)c1.r, (float)c1.g, (float)c1.b };

    for (int y = 0; y < h; ++y) {
        uint8_t* row = img.row(y);
        for (int x = 0; x < w; ++x) {
            float t = ((float)x/w + (float)y/h) * 0.5f;
            Color3f c = {
                f0.r + t * (f1.r - f0.r),
                f0.g + t * (f1.g - f0.g),
                f0.b + t * (f1.b - f0.b)
            };

            // Deterministic pseudo-random coordinate noise for micro-dithering (breaks up color banding)
            float noise = (((x * 12.9898f + y * 78.233f) * 43758.5453f) - std::floor((x * 12.9898f + y * 78.233f) * 43758.5453f));
            float dither = (noise - 0.5f) * 1.0f;

            row[x*4+0] = (uint8_t)std::clamp(c.r + dither, 0.0f, 255.0f);
            row[x*4+1] = (uint8_t)std::clamp(c.g + dither, 0.0f, 255.0f);
            row[x*4+2] = (uint8_t)std::clamp(c.b + dither, 0.0f, 255.0f);
            row[x*4+3] = 255;
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shadow blur đơn giản: box blur 1 pass trên shadow mask
// Nhanh hơn Gaussian nhưng trông vẫn mịn ổn
// ─────────────────────────────────────────────────────────────────────────────

static void draw_shadow(Image& dst, int x0, int y0, int sw, int sh,
                         int radius_px, int blur, uint8_t alpha) {
    // Tạo shadow buffer nhỏ rồi scale up — như code Qt cũ (BLK=8)
    constexpr int BLK = 8;
    int bw = (dst.w + BLK - 1) / BLK;
    int bh = (dst.h + BLK - 1) / BLK;

    std::vector<float> shadow(bw * bh, 0.0f);

    // Vẽ filled rect vào buffer nhỏ
    int bx0 = x0 / BLK, by0 = (y0 + 10) / BLK;  // offset shadow xuống 10px
    int bx1 = (x0 + sw) / BLK, by1 = (y0 + sh) / BLK;
    int br  = radius_px / BLK;

    for (int by = by0; by <= by1 && by < bh; ++by) {
        for (int bx = bx0; bx <= bx1 && bx < bw; ++bx) {
            // Rounded corner check
            int lcx = std::max(0, std::max(bx0 + br - bx - 1, bx - (bx1 - br)));
            int lcy = std::max(0, std::max(by0 + br - by - 1, by - (by1 - br)));
            if (lcx*lcx + lcy*lcy <= br*br) {
                shadow[by * bw + bx] = 1.0f;
            }
        }
    }

    // Box blur 2 lần trên buffer nhỏ
    std::vector<float> tmp(bw * bh, 0.0f);
    int bblur = std::max(1, blur / BLK);
    for (int pass = 0; pass < 2; ++pass) {
        // horizontal
        for (int by = 0; by < bh; ++by) {
            float sum = 0; int cnt = 0;
            for (int bx = -bblur; bx <= bblur; ++bx) {
                int nx = bx;
                if (nx >= 0 && nx < bw) { sum += shadow[by*bw+nx]; cnt++; }
            }
            for (int bx = 0; bx < bw; ++bx) {
                tmp[by*bw+bx] = cnt > 0 ? sum/cnt : 0;
                int add = bx+bblur+1; if (add < bw) { sum += shadow[by*bw+add]; cnt++; }
                int rem = bx-bblur;   if (rem >= 0) { sum -= shadow[by*bw+rem]; cnt--; }
            }
        }
        // vertical
        for (int bx = 0; bx < bw; ++bx) {
            float sum = 0; int cnt = 0;
            for (int by = -bblur; by <= bblur; ++by) {
                int ny = by;
                if (ny >= 0 && ny < bh) { sum += tmp[ny*bw+bx]; cnt++; }
            }
            for (int by = 0; by < bh; ++by) {
                shadow[by*bw+bx] = cnt > 0 ? sum/cnt : 0;
                int add = by+bblur+1; if (add < bh) { sum += tmp[add*bw+bx]; cnt++; }
                int rem = by-bblur;   if (rem >= 0) { sum -= tmp[rem*bw+bx]; cnt--; }
            }
        }
    }

    // Upscale và blend vào dst
    for (int y = 0; y < dst.h; ++y) {
        uint8_t* drow = dst.row(y);
        int by = std::min(y / BLK, bh - 1);
        for (int x = 0; x < dst.w; ++x) {
            int bx = std::min(x / BLK, bw - 1);
            float v = shadow[by * bw + bx];
            if (v <= 0.001f) continue;
            uint8_t sa = (uint8_t)(v * alpha);
            blend_over(drow + x*4, 0, 0, 0, sa);
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composite: vẽ src (RGBA) lên dst tại offset (ox, oy)
// ─────────────────────────────────────────────────────────────────────────────

static void composite(Image& dst, const Image& src, int ox, int oy) {
    for (int y = 0; y < src.h; ++y) {
        int dy = oy + y;
        if (dy < 0 || dy >= dst.h) continue;
        const uint8_t* srow = src.row(y);
        uint8_t*       drow = dst.row(dy);
        for (int x = 0; x < src.w; ++x) {
            int dx = ox + x;
            if (dx < 0 || dx >= dst.w) continue;
            const uint8_t* s = srow + x*4;
            blend_over(drow + dx*4, s[0], s[1], s[2], s[3]);
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parse hex color "#RRGGBB"
// ─────────────────────────────────────────────────────────────────────────────

static Color3 hex(const char* s) {
    if (*s == '#') s++;
    unsigned v = (unsigned)strtoul(s, nullptr, 16);
    return { (uint8_t)((v>>16)&0xFF), (uint8_t)((v>>8)&0xFF), (uint8_t)(v&0xFF) };
}

// ─────────────────────────────────────────────────────────────────────────────
// Bảng gradient
// ─────────────────────────────────────────────────────────────────────────────

static const struct { const char* a; const char* b; } GRADIENTS[] = {
    {"#cba6f7", "#89b4fa"}, // Catppuccin Pastel (Mauve to Blue)
    {"#f38ba8", "#cba6f7"}, // Catppuccin Sunset (Red to Mauve)
    {"#f72585", "#7209b7"}, // Cyber Neon (Pink to Purple)
    {"#3a7bd5", "#3a6073"}, // Premium Slate Blue
    {"#00c6ff", "#0072ff"}, // Vibrant Azure
    {"#ff007f", "#7f00ff"}, // Electric Magenta to Violet
    {"#a1c4fd", "#c2e9fb"}, // Elegant Ice Blue
    {"#111726", "#2d3c59"}, // Luxury Stealth Navy
    {"#fc6767", "#ec008c"}, // Warm Neon Sunset
    {"#642B73", "#C6426E"}, // Plum Velvet
    {"#243B55", "#141E30"}, // Matte Space Gray
    {"#00F260", "#0575E6"}, // Mint Aurora to Deep Sea
    {"#fa709a", "#fee140"}, // Soft Coral Pink to Lemon
    {"#1e3c72", "#2a5298"}, // Deep Royal Navy
    {"#ee0979", "#ff6a00"}, // High-voltage Citrus
    {"#8A2387", "#E94057"}, // Cosmic Berry
    {"#ff758c", "#ff7eb3"}, // Sweet Rose Water
    {"#ff9900", "#ff5b00"}, // Golden Ember
    {"#4facfe", "#00f2fe"}, // Cool Aqua
    {"#b224ef", "#7579ff"}, // Psychedelic Violet
    {"#0250c5", "#d43f8d"}, // Intense Purple-Pink
    {"#85FFBD", "#FFFB7D"}, // Fresh Spring Mint
    {"#130CB7", "#52E5E7"}, // Futuristic Deep Blue to Cyan
    {"#F40076", "#DF580A"}  // Ignite Orange-Pink
};
constexpr int GRADIENT_COUNT = (int)(sizeof(GRADIENTS)/sizeof(GRADIENTS[0]));

// ─────────────────────────────────────────────────────────────────────────────
// BEAUTIFY
// ─────────────────────────────────────────────────────────────────────────────

static void beautify(const char* inputPath, const char* outputPath) {
    Image input = load_png(inputPath);
    if (!input.ok()) { std::cerr << "Failed to load: " << inputPath << '\n'; return; }

    const int sw = input.w;
    const int sh = input.h;
    const double uiScale = std::max(1.0, sw / 1920.0);
    const int bar_h   = (int)(32 * uiScale);
    const int padding = (int)(60 * uiScale);
    const int radius  = (int)(14 * uiScale);
    const int b_rad   = (int)(7  * uiScale);
    const int combined_h = sh + bar_h;

    // ── Bước 1: Decorated window (title bar + screenshot) ────────────────
    Image combined;
    combined.w = sw; combined.h = combined_h;
    combined.px.assign((size_t)sw * combined_h * 4, 0);

    // Title bar #1e1e1e
    {
        Color3 bar = hex("#1e1e1e");
        for (int y = 0; y < bar_h; ++y) {
            uint8_t* row = combined.row(y);
            for (int x = 0; x < sw; ++x) {
                row[x*4+0] = bar.r;
                row[x*4+1] = bar.g;
                row[x*4+2] = bar.b;
                row[x*4+3] = 255;
            }
        }
    }

    // Copy screenshot vào bên dưới title bar
    for (int y = 0; y < sh; ++y) {
        memcpy(combined.row(bar_h + y), input.row(y), sw * 4);
        // Đảm bảo alpha = 255 (grim output thường là RGB)
        uint8_t* r = combined.row(bar_h + y);
        for (int x = 0; x < sw; ++x) r[x*4+3] = 255;
    }

    // Traffic light buttons
    const int btn_y = (int)(16 * uiScale);
    draw_ellipse(combined, (int)(24*uiScale), btn_y, b_rad, b_rad, 0xFF, 0x5F, 0x56);
    draw_ellipse(combined, (int)(46*uiScale), btn_y, b_rad, b_rad, 0xFF, 0xBD, 0x2E);
    draw_ellipse(combined, (int)(68*uiScale), btn_y, b_rad, b_rad, 0x27, 0xC9, 0x3F);

    // Rounded corners mask
    apply_rounded_mask(combined, radius);

    // ── Bước 2: Final image với gradient + shadow ────────────────────────
    const int final_w = sw + padding * 2;
    const int final_h = combined_h + padding * 2;

    Image finalImg;
    finalImg.w = final_w; finalImg.h = final_h;
    finalImg.px.resize((size_t)final_w * final_h * 4);

    // Random gradient
    std::srand((unsigned)std::time(nullptr));
    int gi = std::rand() % GRADIENT_COUNT;
    fill_gradient(finalImg, hex(GRADIENTS[gi].a), hex(GRADIENTS[gi].b));

    // Shadow
    draw_shadow(finalImg, padding, padding, sw, combined_h, radius, 24, 110);

    // Composite decorated window
    composite(finalImg, combined, padding, padding);

    // ── Bước 3: Save ─────────────────────────────────────────────────────
    save_png_rgb(outputPath, finalImg, 1);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN QR (giữ nguyên logic zbar như cũ, chỉ bỏ Qt)
// ─────────────────────────────────────────────────────────────────────────────

static void scan_qr(const char* inputPath) {
    // Load bằng libpng
    Image img = load_png(inputPath);
    if (!img.ok()) return;

    auto do_scan = [](const Image& src, int div) -> bool {
        // Convert sang grayscale
        std::vector<uint8_t> gray;
        gray.reserve((size_t)src.w * src.h);
        for (int y = 0; y < src.h; ++y) {
            const uint8_t* row = src.row(y);
            for (int x = 0; x < src.w; ++x) {
                // Luma BT.601
                int l = (row[x*4]*299 + row[x*4+1]*587 + row[x*4+2]*114) / 1000;
                gray.push_back((uint8_t)l);
            }
        }

        zbar::ImageScanner scanner;
        scanner.set_config(zbar::ZBAR_NONE, zbar::ZBAR_CFG_ENABLE, 1);
        zbar::Image zimg(src.w, src.h, "Y800", gray.data(), (size_t)src.w * src.h);
        if (scanner.scan(zimg) <= 0) return false;

        for (auto sym = zimg.symbol_begin(); sym != zimg.symbol_end(); ++sym) {
            int min_x=INT_MAX, min_y=INT_MAX, max_x=INT_MIN, max_y=INT_MIN;
            for (int i = 0, n = sym->get_location_size(); i < n; ++i) {
                int px = sym->get_location_x(i) / div;
                int py = sym->get_location_y(i) / div;
                min_x=std::min(min_x,px); max_x=std::max(max_x,px);
                min_y=std::min(min_y,py); max_y=std::max(max_y,py);
            }
            std::cout << min_x << ',' << min_y << ','
                      << (max_x-min_x) << ',' << (max_y-min_y)
                      << "|||" << sym->get_data() << '\n';
        }
        return true;
    };

    if (!do_scan(img, 1)) {
        // Thử scale x2
        int w2 = img.w*2, h2 = img.h*2;
        Image scaled;
        scaled.w = w2; scaled.h = h2;
        scaled.px.resize((size_t)w2 * h2 * 4);
        // Bilinear upscale đơn giản (nearest là đủ cho QR detection)
        for (int y = 0; y < h2; ++y) {
            uint8_t* drow = scaled.row(y);
            const uint8_t* srow = img.row(y/2);
            for (int x = 0; x < w2; ++x) {
                memcpy(drow + x*4, srow + (x/2)*4, 4);
            }
        }
        do_scan(scaled, 2);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────────────────────

int main(int argc, char* argv[]) {
    if (argc < 2) return 1;
    const char* cmd = argv[1];
    if (cmd[0] == 'b' && argc >= 4) {
        beautify(argv[2], argv[3]);
    } else if (cmd[0] == 's' && argc >= 3) {
        scan_qr(argv[2]);
    } else {
        std::cerr << "Usage:\n"
                  << "  " << argv[0] << " beautify <in.png> <out.png>\n"
                  << "  " << argv[0] << " scan     <in.png>\n";
        return 1;
    }
    return 0;
}