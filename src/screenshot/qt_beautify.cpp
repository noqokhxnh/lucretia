#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QLinearGradient>
#include <QColor>
#include <QGuiApplication>
#include <QScreen>
#include <chrono>
#include <iostream>
#include <vector>

const std::vector<std::pair<QColor, QColor>> GRADIENTS = {
    {QColor("#4facfe"), QColor("#00f2fe")}, {QColor("#ff9a9e"), QColor("#fecfef")}, 
    {QColor("#a18cd1"), QColor("#fbc2eb")}, {QColor("#84fab0"), QColor("#8fd3f4")}, 
    {QColor("#fccb90"), QColor("#d57eeb")}, {QColor("#e0c3fc"), QColor("#8ec5fc")},
    {QColor("#f093fb"), QColor("#f5576c")}, {QColor("#43e97b"), QColor("#38f9d7")}, 
    {QColor("#fa709a"), QColor("#fee140")}, {QColor("#30cfd0"), QColor("#330867")}, 
    {QColor("#a8edea"), QColor("#fed6e3")}, {QColor("#89f7fe"), QColor("#66a6ff")},
    {QColor("#ff0844"), QColor("#ffb199")}, {QColor("#96fbc4"), QColor("#f9f586")}, 
    {QColor("#2af598"), QColor("#009efd")}, {QColor("#cd9cf2"), QColor("#f6f3ff")}, 
    {QColor("#1e3c72"), QColor("#2a5298")}, {QColor("#ff758c"), QColor("#ff7eb3")},
    {QColor("#b224ef"), QColor("#7579ff")}, {QColor("#f43b47"), QColor("#453a94")}, 
    {QColor("#0250c5"), QColor("#d43f8d")}
};

int main(int argc, char* argv[]) {
    if (argc < 3) return 1;
    
    auto start = std::chrono::high_resolution_clock::now();

    QImage input;
    if (!input.load(argv[1])) return 1;

    int scale = 2;
    QImage screenshot = input.scaled(input.width() * scale, input.height() * scale, Qt::IgnoreAspectRatio, Qt::FastTransformation);

    int bar_h = 32 * scale;
    int padding = 60 * scale;
    int radius = 14 * scale;
    int b_rad = 7 * scale;

    int w = screenshot.width();
    int h = screenshot.height();
    int combined_h = h + bar_h;

    QImage combined(w, combined_h, QImage::Format_ARGB32_Premultiplied);
    combined.fill(Qt::transparent);

    QPainter p(&combined);
    p.setRenderHint(QPainter::Antialiasing);

    // Rounded corners mask
    QPainterPath path;
    path.addRoundedRect(0, 0, w, combined_h, radius, radius);
    p.setClipPath(path);

    // Title bar
    p.fillRect(0, 0, w, bar_h, QColor("#1e1e1e"));
    
    // Buttons
    p.setBrush(QColor("#FF5F56")); p.setPen(Qt::NoPen);
    p.drawEllipse(24 * scale - b_rad, 16 * scale - b_rad, b_rad * 2, b_rad * 2);
    p.setBrush(QColor("#FFBD2E"));
    p.drawEllipse(46 * scale - b_rad, 16 * scale - b_rad, b_rad * 2, b_rad * 2);
    p.setBrush(QColor("#27C93F"));
    p.drawEllipse(68 * scale - b_rad, 16 * scale - b_rad, b_rad * 2, b_rad * 2);

    // Screenshot
    p.drawImage(0, bar_h, screenshot);
    p.end();

    // Background
    int bg_w = w + padding * 2;
    int bg_h = combined_h + padding * 2;
    QImage bg(bg_w, bg_h, QImage::Format_ARGB32_Premultiplied);
    
    QPainter p_bg(&bg);
    p_bg.setRenderHint(QPainter::Antialiasing);
    
    // Random gradient
    srand(time(NULL));
    auto grad_pair = GRADIENTS[rand() % GRADIENTS.size()];
    QLinearGradient grad(0, 0, bg_w, bg_h);
    grad.setColorAt(0, grad_pair.first);
    grad.setColorAt(1, grad_pair.second);
    p_bg.fillRect(bg.rect(), grad);

    // Shadow (Very simple: draw a dark blurred rect)
    // For true blur we'd need a convolution but let's try a simple approach first
    p_bg.setOpacity(0.5);
    p_bg.setBrush(QColor(0, 0, 0));
    p_bg.drawRoundedRect(padding, padding + 10 * scale, w, combined_h, radius, radius);
    p_bg.setOpacity(1.0);

    // Composite
    p_bg.drawImage(padding, padding, combined);
    p_bg.end();

    bg.save(argv[2], "PNG", 100);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end - start;
    std::cout << "Time: " << diff.count() << "s" << std::endl;

    return 0;
}
