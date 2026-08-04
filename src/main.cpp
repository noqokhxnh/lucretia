#include <QCoreApplication>
#include "core/ipc_server.hpp"

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);

    DaemonServer server;

    return app.exec();
}
