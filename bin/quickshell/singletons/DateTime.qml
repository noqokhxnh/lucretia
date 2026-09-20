pragma Singleton
import QtQuick
import Quickshell
import "../"

Item {
    id: root

    property var timeNow: new Date()
    property var dateNow: new Date()
    property alias now: root.timeNow

    readonly property string timeFormat: {
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.time && Config.rawSettings.bar.time.format !== undefined) {
                return Config.rawSettings.bar.time.format;
            }
            if (Config.rawSettings.general && Config.rawSettings.general.time_format !== undefined) {
                return Config.rawSettings.general.time_format;
            }
        }
        return "HH:mm:ss";
    }

    readonly property string hourFormat: {
        if (timeFormat.indexOf("HH") !== -1) return "HH";
        if (timeFormat.indexOf("hh") !== -1) return "hh";
        if (timeFormat.indexOf("H") !== -1) return "H";
        if (timeFormat.indexOf("h") !== -1) return "h";
        return "HH";
    }

    readonly property string minuteFormat: {
        if (timeFormat.indexOf("mm") !== -1) return "mm";
        if (timeFormat.indexOf("m") !== -1) return "m";
        return "mm";
    }

    readonly property string secondFormat: {
        if (timeFormat.indexOf("ss") !== -1) return "ss";
        if (timeFormat.indexOf("s") !== -1) return "s";
        return "";
    }

    readonly property string amPmFormat: {
        if (timeFormat.indexOf("AP") !== -1) return "AP";
        if (timeFormat.indexOf("ap") !== -1) return "ap";
        if (timeFormat.indexOf("A") !== -1 || timeFormat.indexOf("a") !== -1) return "AP";
        return "";
    }

    readonly property bool is12Hour: amPmFormat !== "" || hourFormat === "hh" || hourFormat === "h"

    readonly property string time: Qt.formatDateTime(timeNow, timeFormat)
    readonly property string timeShort: Qt.formatDateTime(timeNow, hourFormat + ":" + minuteFormat + (amPmFormat !== "" ? " " + amPmFormat : ""))
    readonly property string timeLong: Qt.formatDateTime(timeNow, "HH:mm:ss")
    readonly property string timeOnly: Qt.formatDateTime(timeNow, timeFormat)

    readonly property string hour: Qt.formatDateTime(timeNow, hourFormat)
    readonly property string minute: Qt.formatDateTime(timeNow, minuteFormat)
    readonly property string second: secondFormat !== "" ? Qt.formatDateTime(timeNow, secondFormat) : ""
    readonly property string amPm: amPmFormat !== "" ? Qt.formatDateTime(timeNow, amPmFormat) : ""

    readonly property bool isVi: typeof I18n !== "undefined" && I18n.currentLang === "vi"

    readonly property var viDays: ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
    readonly property var viDaysShort: ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
    readonly property var viMonths: ["Tháng 1", "Tháng 2", "Tháng 3", "Tháng 4", "Tháng 5", "Tháng 6", "Tháng 7", "Tháng 8", "Tháng 9", "Tháng 10", "Tháng 11", "Tháng 12"]
    readonly property var viMonthsShort: ["Th1", "Th2", "Th3", "Th4", "Th5", "Th6", "Th7", "Th8", "Th9", "Th10", "Th11", "Th12"]

    readonly property string day: Qt.formatDateTime(dateNow, "dd")
    readonly property string dayShort: Qt.formatDateTime(dateNow, "d")
    readonly property string dayName: isVi ? viDays[dateNow.getDay()] : Qt.formatDateTime(dateNow, "dddd")
    readonly property string dayNameShort: isVi ? viDaysShort[dateNow.getDay()] : Qt.formatDateTime(dateNow, "ddd")
    readonly property string month: isVi ? viMonths[dateNow.getMonth()] : Qt.formatDateTime(dateNow, "MMMM")
    readonly property string monthShort: isVi ? viMonthsShort[dateNow.getMonth()] : Qt.formatDateTime(dateNow, "MMM")
    readonly property string year: Qt.formatDateTime(dateNow, "yyyy")

    readonly property string fullDate: isVi ? (dayName + ", " + dateNow.getDate() + " " + month.toLowerCase()) : Qt.formatDateTime(dateNow, "dddd, MMMM dd")
    readonly property string shortDate: isVi ? (dateNow.getDate() + " " + monthShort) : Qt.formatDateTime(dateNow, "d MMM")
    readonly property string dateBadge: shortDate.toUpperCase()

    function format(pattern, dateObj) {
        return Qt.formatDateTime(dateObj || timeNow, pattern);
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date();
            root.timeNow = d;
            if (d.getDate() !== root.dateNow.getDate() || d.getMonth() !== root.dateNow.getMonth() || d.getFullYear() !== root.dateNow.getFullYear()) {
                root.dateNow = d;
            }
        }
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            let d = new Date();
            root.timeNow = d;
            root.dateNow = d;
        }
    }
}
