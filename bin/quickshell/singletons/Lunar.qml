pragma Singleton
import QtQuick
import Quickshell
import "LunarCalendar.js" as LunarCalc
import "../"
import "../singletons"

Item {
    id: root

    property var now: DateTime.now || new Date()
    property bool isEn: I18n.currentLang !== "vi"

    property var details: LunarCalc.getFullDetails(root.now, root.isEn, 7)

    readonly property int solarDay: details ? details.solarDay : root.now.getDate()
    readonly property int solarMonth: details ? details.solarMonth : (root.now.getMonth() + 1)
    readonly property int solarYear: details ? details.solarYear : root.now.getFullYear()

    readonly property int lunarDay: details ? details.lunarDay : 1
    readonly property int lunarMonth: details ? details.lunarMonth : 1
    readonly property int lunarYear: details ? details.lunarYear : root.now.getFullYear()
    readonly property bool isLeap: details ? details.isLeap : false

    readonly property string dayStr: details ? details.dayStr : ""
    readonly property string monthName: details ? details.monthName : ""
    readonly property string canChiYear: details ? details.canChiYear : ""
    readonly property string canChiMonth: details ? details.canChiMonth : ""
    readonly property string canChiDay: details ? details.canChiDay : ""
    readonly property string canChiHour: details ? details.canChiHour : ""
    readonly property string animal: details ? details.animal : ""

    readonly property string solarTerm: details ? details.solarTerm : ""
    readonly property var zodiacHours: details ? details.zodiacHours : []
    readonly property var zodiacHoursShort: details ? details.zodiacHoursShort : []
    readonly property string zodiacHoursStr: (zodiacHoursShort && zodiacHoursShort.length > 0) ? zodiacHoursShort.join(", ") : ""

    readonly property string dayZodiacName: (details && details.dayZodiac) ? details.dayZodiac.name : ""
    readonly property string dayZodiacType: (details && details.dayZodiac) ? details.dayZodiac.type : ""
    readonly property bool isAuspiciousDay: (details && details.dayZodiac) ? details.dayZodiac.isAuspicious : false

    readonly property string festival: details ? details.festival : ""
    readonly property string moonPhaseIcon: (details && details.moon) ? details.moon.icon : "󰽢"
    readonly property string moonPhaseName: (details && details.moon) ? details.moon.name : ""

    function updateDetails() {
        root.details = LunarCalc.getFullDetails(root.now, root.isEn, 7);
    }

    onNowChanged: updateDetails()
    onIsEnChanged: updateDetails()

    Connections {
        target: DateTime
        function onNowChanged() {
            root.now = DateTime.now;
        }
    }

    Connections {
        target: I18n
        function onLanguageChanged() {
            root.isEn = (I18n.currentLang !== "vi");
            root.updateDetails();
        }
    }

    function getDetailsForDate(d, m, y) {
        let dateObj = new Date(y, m - 1, d);
        return LunarCalc.getFullDetails(dateObj, root.isEn, 7);
    }

    function getMonthGrid(targetYear, targetMonth) {
        // targetMonth is 0-indexed (0 = Jan, 11 = Dec)
        let actualToday = new Date();
        let isCurrentMonthToday = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        let firstDayIndex = new Date(targetYear, targetMonth, 1).getDay();
        // Monday = 0, Sunday = 6
        firstDayIndex = (firstDayIndex === 0) ? 6 : firstDayIndex - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        let result = [];

        // Previous month filler days
        for (let i = firstDayIndex - 1; i >= 0; i--) {
            let dayNum = daysInPrevMonth - i;
            let pMonth = (targetMonth === 0) ? 12 : targetMonth;
            let pYear = (targetMonth === 0) ? targetYear - 1 : targetYear;
            let lunarInfo = LunarCalc.solar2lunar(dayNum, pMonth, pYear, 7);
            let lunarDayText = lunarInfo.day === 1 ? (lunarInfo.day + "/" + lunarInfo.month) : String(lunarInfo.day);

            result.push({
                solarDay: dayNum,
                solarMonth: pMonth,
                solarYear: pYear,
                lunarDay: lunarInfo.day,
                lunarMonth: lunarInfo.month,
                lunarYear: lunarInfo.year,
                lunarDayText: lunarDayText,
                isCurrentMonth: false,
                isToday: false,
                isLunar1st: lunarInfo.day === 1,
                isLunar15th: lunarInfo.day === 15,
                festival: LunarCalc.getFestival(lunarInfo.day, lunarInfo.month, lunarInfo.leap, root.isEn)
            });
        }

        // Current month days
        for (let i = 1; i <= daysInMonth; i++) {
            let lunarInfo = LunarCalc.solar2lunar(i, targetMonth + 1, targetYear, 7);
            let lunarDayText = lunarInfo.day === 1 ? (lunarInfo.day + "/" + lunarInfo.month) : String(lunarInfo.day);

            result.push({
                solarDay: i,
                solarMonth: targetMonth + 1,
                solarYear: targetYear,
                lunarDay: lunarInfo.day,
                lunarMonth: lunarInfo.month,
                lunarYear: lunarInfo.year,
                lunarDayText: lunarDayText,
                isCurrentMonth: true,
                isToday: (isCurrentMonthToday && i === todayDate),
                isLunar1st: lunarInfo.day === 1,
                isLunar15th: lunarInfo.day === 15,
                festival: LunarCalc.getFestival(lunarInfo.day, lunarInfo.month, lunarInfo.leap, root.isEn)
            });
        }

        // Next month filler days (up to 42 cells)
        let remaining = 42 - result.length;
        for (let i = 1; i <= remaining; i++) {
            let nMonth = (targetMonth === 11) ? 1 : targetMonth + 2;
            let nYear = (targetMonth === 11) ? targetYear + 1 : targetYear;
            let lunarInfo = LunarCalc.solar2lunar(i, nMonth, nYear, 7);
            let lunarDayText = lunarInfo.day === 1 ? (lunarInfo.day + "/" + lunarInfo.month) : String(lunarInfo.day);

            result.push({
                solarDay: i,
                solarMonth: nMonth,
                solarYear: nYear,
                lunarDay: lunarInfo.day,
                lunarMonth: lunarInfo.month,
                lunarYear: lunarInfo.year,
                lunarDayText: lunarDayText,
                isCurrentMonth: false,
                isToday: false,
                isLunar1st: lunarInfo.day === 1,
                isLunar15th: lunarInfo.day === 15,
                festival: LunarCalc.getFestival(lunarInfo.day, lunarInfo.month, lunarInfo.leap, root.isEn)
            });
        }

        return result;
    }
}
