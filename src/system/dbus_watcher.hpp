#ifndef DBUS_WATCHER_HPP
#define DBUS_WATCHER_HPP

#include <QObject>
#include <QDBusConnection>
#include <QDBusInterface>

class DBusWatcherService : public QObject {
    Q_OBJECT

public:
    explicit DBusWatcherService(QObject* parent = nullptr);

signals:
    void powerStateChanged(bool onBattery);
    void networkStateChanged();
    void bluetoothStateChanged();

private slots:
    void onUPowerPropertiesChanged(const QString& interface, const QVariantMap& changedProps, const QStringList& invalidatedProps);
};

#endif // DBUS_WATCHER_HPP
