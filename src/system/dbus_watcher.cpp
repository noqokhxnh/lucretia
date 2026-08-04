#include "dbus_watcher.hpp"
#include <QDBusMessage>

DBusWatcherService::DBusWatcherService(QObject* parent) : QObject(parent) {
    QDBusConnection sysBus = QDBusConnection::systemBus();
    if (sysBus.isConnected()) {
        // UPower Battery/AC monitoring
        sysBus.connect(
            "org.freedesktop.UPower",
            "/org/freedesktop/UPower",
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            this,
            SLOT(onUPowerPropertiesChanged(QString, QVariantMap, QStringList))
        );
    }
}

void DBusWatcherService::onUPowerPropertiesChanged(const QString& interface, const QVariantMap& changedProps, const QStringList&) {
    if (interface == "org.freedesktop.UPower") {
        if (changedProps.contains("OnBattery")) {
            emit powerStateChanged(changedProps.value("OnBattery").toBool());
        }
    }
}
