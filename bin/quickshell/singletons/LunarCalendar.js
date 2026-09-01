// Vietnamese Lunar Calendar astronomical calculations (Thuật toán Hồ Ngọc Đức, UTC+7)
.pragma library

const CAN = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"];
const CHI = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"];
const CHI_ANIMALS_VI = ["Chuột", "Trâu", "Hổ", "Mèo", "Rồng", "Rắn", "Ngựa", "Dê", "Khỉ", "Gà", "Chó", "Lợn"];
const CHI_ANIMALS_EN = ["Rat", "Ox", "Tiger", "Cat", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"];

const MONTH_NAMES_VI = [
    "Tháng Giêng", "Tháng Hai", "Tháng Ba", "Tháng Tư", "Tháng Năm", "Tháng Sáu",
    "Tháng Bảy", "Tháng Tám", "Tháng Chín", "Tháng Mười", "Tháng Mười Một", "Tháng Chạp"
];

const MONTH_NAMES_EN = [
    "1st Month", "2nd Month", "3rd Month", "4th Month", "5th Month", "6th Month",
    "7th Month", "8th Month", "9th Month", "10th Month", "11th Month", "12th Month"
];

const TIET_KHI = [
    "Xuân Phân", "Thanh Minh", "Cốc Vũ", "Lập Hạ", "Tiểu Mãn", "Mang Chủng",
    "Hạ Chí", "Tiểu Thử", "Đại Thử", "Lập Thu", "Xử Thử", "Bạch Lộ",
    "Thu Phân", "Hàn Lộ", "Sương Giáng", "Lập Đông", "Tiểu Tuyết", "Đại Tuyết",
    "Đông Chí", "Tiểu Hàn", "Đại Hàn", "Lập Xuân", "Vũ Thủy", "Kinh Trập"
];

const TIET_KHI_EN = [
    "Spring Equinox", "Pure Brightness", "Grain Rain", "Start of Summer", "Grain Buds", "Grain in Ear",
    "Summer Solstice", "Minor Heat", "Major Heat", "Start of Autumn", "End of Heat", "White Dew",
    "Autumn Equinox", "Cold Dew", "Frost's Descent", "Start of Winter", "Minor Snow", "Major Snow",
    "Winter Solstice", "Minor Cold", "Major Cold", "Start of Spring", "Rain Water", "Insects Awakening"
];

const ZODIAC_PATTERNS = {
    0: [0, 1, 3, 6, 8, 9],       // Tý: Tý, Sửu, Mão, Ngọ, Thân, Dậu
    6: [0, 1, 3, 6, 8, 9],       // Ngọ
    1: [2, 3, 5, 8, 10, 11],     // Sửu: Dần, Mão, Tỵ, Thân, Tuất, Hợi
    7: [2, 3, 5, 8, 10, 11],     // Mùi
    2: [0, 1, 4, 5, 7, 10],      // Dần: Tý, Sửu, Thìn, Tỵ, Mùi, Tuất
    8: [0, 1, 4, 5, 7, 10],      // Thân
    3: [0, 2, 3, 6, 7, 9],       // Mão: Tý, Dần, Mão, Ngọ, Mùi, Dậu
    9: [0, 2, 3, 6, 7, 9],       // Dậu
    4: [2, 4, 5, 8, 9, 11],      // Thìn: Dần, Thìn, Tỵ, Thân, Dậu, Hợi
    10: [2, 4, 5, 8, 9, 11],     // Tuất
    5: [1, 4, 6, 7, 10, 11],     // Tỵ: Sửu, Thìn, Ngọ, Mùi, Tuất, Hợi
    11: [1, 4, 6, 7, 10, 11]     // Hợi
};

const HOANG_DAO_NAMES = [
    { name: "Thanh Long", isAuspicious: true },
    { name: "Minh Đường", isAuspicious: true },
    { name: "Thiên Hình", isAuspicious: false },
    { name: "Chu Tước", isAuspicious: false },
    { name: "Kim Quỹ", isAuspicious: true },
    { name: "Bảo Quang", isAuspicious: true },
    { name: "Bạch Hổ", isAuspicious: false },
    { name: "Ngọc Đường", isAuspicious: true },
    { name: "Thiên Lao", isAuspicious: false },
    { name: "Huyền Vũ", isAuspicious: false },
    { name: "Tư Mệnh", isAuspicious: true },
    { name: "Câu Trận", isAuspicious: false }
];

function jdFromDate(dd, mm, yy) {
    let a = Math.floor((14 - mm) / 12);
    let y = yy + 4800 - a;
    let m = mm + 12 * a - 3;
    return dd + Math.floor((153 * m + 2) / 5) + 365 * y + Math.floor(y / 4) - Math.floor(y / 100) + Math.floor(y / 400) - 32045;
}

function jdToDate(jd) {
    let a = jd + 32044;
    let b = Math.floor((4 * a + 3) / 146097);
    let c = a - Math.floor(146097 * b / 4);
    let d = Math.floor((4 * c + 3) / 1461);
    let e = c - Math.floor(1461 * d / 4);
    let m = Math.floor((5 * e + 2) / 153);
    let day = e - Math.floor((153 * m + 2) / 5) + 1;
    let month = m + 3 - 12 * Math.floor(m / 10);
    let year = 100 * b + d - 4800 + Math.floor(m / 10);
    return [day, month, year];
}

function getNewMoonDay(k, timeZone) {
    let T = k / 1236.85;
    let T2 = T * T;
    let T3 = T2 * T;
    let dr = Math.PI / 180;
    let Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3;
    Jd1 = Jd1 + 0.00033 * Math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr);
    let M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3;
    let Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3;
    let F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3;
    let C1 = (0.1734 - 0.000393 * T) * Math.sin(M * dr) + 0.0021 * Math.sin(2 * M * dr);
    C1 = C1 - 0.4068 * Math.sin(Mpr * dr) + 0.0161 * Math.sin(2 * Mpr * dr);
    C1 = C1 - 0.0004 * Math.sin(3 * Mpr * dr);
    C1 = C1 + 0.0104 * Math.sin(2 * F * dr) - 0.0051 * Math.sin((M + Mpr) * dr);
    C1 = C1 - 0.0074 * Math.sin((M - Mpr) * dr) + 0.0004 * Math.sin((2 * F + M) * dr);
    C1 = C1 - 0.0004 * Math.sin((2 * F - M) * dr) - 0.0006 * Math.sin((2 * F + Mpr) * dr);
    C1 = C1 + 0.0010 * Math.sin((2 * F - Mpr) * dr) + 0.0005 * Math.sin((M + 2 * Mpr) * dr);
    let deltat;
    if (T < -11) {
        deltat = 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3;
    } else {
        deltat = -0.000278 + 0.000265 * T + 0.000262 * T2;
    }
    let JdNew = Jd1 + C1 - deltat;
    return Math.floor(JdNew + 0.5 + timeZone / 24);
}

function getSunLongitude(dayNumber, timeZone) {
    let T = (dayNumber - 2451545.5 - timeZone / 24) / 36525;
    let T2 = T * T;
    let dr = Math.PI / 180;
    let M = 357.52910 + 35999.05029 * T - 0.0001537 * T2;
    let L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2;
    let DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * Math.sin(M * dr);
    DL = DL + (0.019993 - 0.000101 * T) * Math.sin(2 * M * dr) + 0.000290 * Math.sin(3 * M * dr);
    let L = L0 + DL;
    L = L * dr;
    L = L - Math.PI * 2 * Math.floor(L / (Math.PI * 2));
    return Math.floor(L / Math.PI * 6);
}

function getSunLongitudeDegrees(dayNumber, timeZone) {
    let T = (dayNumber - 2451545.5 - timeZone / 24) / 36525;
    let T2 = T * T;
    let dr = Math.PI / 180;
    let M = 357.52910 + 35999.05029 * T - 0.0001537 * T2;
    let L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2;
    let DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * Math.sin(M * dr);
    DL = DL + (0.019993 - 0.000101 * T) * Math.sin(2 * M * dr) + 0.000290 * Math.sin(3 * M * dr);
    let L = L0 + DL;
    let deg = (L % 360 + 360) % 360;
    return deg;
}

function getLunarMonth11(yy, timeZone) {
    let off = jdFromDate(31, 12, yy) - 2415021;
    let k = Math.floor(off / 29.530588853);
    let nm = getNewMoonDay(k, timeZone);
    let sunLong = getSunLongitude(nm, timeZone);
    if (sunLong >= 9) {
        nm = getNewMoonDay(k - 1, timeZone);
    }
    return nm;
}

function getLeapMonthOffset(a11, timeZone) {
    let k = Math.floor((a11 - 2415021.0769986) / 29.530588853 + 0.5);
    let last = 0;
    let i = 1;
    let arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
    do {
        last = arc;
        i++;
        arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
    } while (arc !== last && i < 14);
    return i - 1;
}

function solar2lunar(dd, mm, yy, timeZone) {
    timeZone = timeZone !== undefined ? timeZone : 7;
    let dayNumber = jdFromDate(dd, mm, yy);
    let k = Math.floor((dayNumber - 2415021.0769986) / 29.530588853);
    let monthStart = getNewMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
        monthStart = getNewMoonDay(k, timeZone);
    }
    let a11 = getLunarMonth11(yy, timeZone);
    let b11 = a11;
    let lunarYear;
    if (a11 >= monthStart) {
        lunarYear = yy;
        a11 = getLunarMonth11(yy - 1, timeZone);
    } else {
        lunarYear = yy + 1;
        b11 = getLunarMonth11(yy + 1, timeZone);
    }
    let lunarDay = dayNumber - monthStart + 1;
    let diff = Math.floor((monthStart - a11) / 29);
    let lunarLeap = 0;
    let lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
        let leapMonthDiff = getLeapMonthOffset(a11, timeZone);
        if (diff >= leapMonthDiff) {
            lunarMonth = diff + 10;
            if (diff === leapMonthDiff) {
                lunarLeap = 1;
            }
        }
    }
    if (lunarMonth > 12) {
        lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
        lunarYear -= 1;
    }
    return {
        day: lunarDay,
        month: lunarMonth,
        year: lunarYear,
        leap: lunarLeap === 1,
        jd: dayNumber
    };
}

function getCanChiYear(lunarYear) {
    let can = CAN[(lunarYear + 6) % 10];
    let chi = CHI[(lunarYear + 8) % 12];
    return can + " " + chi;
}

function getAnimalYear(lunarYear, isEn) {
    let chiIdx = (lunarYear + 8) % 12;
    return isEn ? CHI_ANIMALS_EN[chiIdx] : CHI_ANIMALS_VI[chiIdx];
}

function getCanChiMonth(lunarMonth, lunarYear) {
    let canYearIdx = (lunarYear + 6) % 10;
    let baseCan = (canYearIdx * 2 + 2) % 10;
    let can = CAN[(baseCan + lunarMonth - 1) % 10];
    let chi = CHI[(lunarMonth + 1) % 12];
    return can + " " + chi;
}

function getCanChiDay(jd) {
    let can = CAN[(jd + 9) % 10];
    let chi = CHI[(jd + 1) % 12];
    return can + " " + chi;
}

function getCanChiHour(hour, jd) {
    let chiIdx = Math.floor((hour + 1) / 2) % 12;
    let canDayIdx = (jd + 9) % 10;
    let baseCan = (canDayIdx * 2) % 10;
    let can = CAN[(baseCan + chiIdx) % 10];
    let chi = CHI[chiIdx];
    return can + " " + chi;
}

function getZodiacHours(jd) {
    let dayChiIdx = (jd + 1) % 12;
    let indices = ZODIAC_PATTERNS[dayChiIdx] || [];
    return indices.map(idx => {
        let name = CHI[idx];
        let range = idx === 0 ? "23h-1h" : `${idx * 2 - 1}h-${idx * 2 + 1}h`;
        return `${name} (${range})`;
    });
}

function getZodiacHoursShort(jd) {
    let dayChiIdx = (jd + 1) % 12;
    let indices = ZODIAC_PATTERNS[dayChiIdx] || [];
    return indices.map(idx => CHI[idx]);
}

function getSolarTerm(jd, isEn, timeZone) {
    let deg = getSunLongitudeDegrees(jd, timeZone !== undefined ? timeZone : 7);
    let idx = Math.floor(deg / 15);
    return isEn ? TIET_KHI_EN[idx] : TIET_KHI[idx];
}

function getDayZodiac(lunarMonth, jd) {
    let dayChiIdx = (jd + 1) % 12;
    // Month base Chi: Thg 1 & 7 là Tý, Thg 2 & 8 là Dần, Thg 3 & 9 là Thìn, Thg 4 & 10 là Ngọ, Thg 5 & 11 là Thân, Thg 6 & 12 là Tuất
    let monthGroup = (lunarMonth - 1) % 6;
    let baseChi = monthGroup * 2;
    let offset = (dayChiIdx - baseChi + 12) % 12;
    let item = HOANG_DAO_NAMES[offset] || HOANG_DAO_NAMES[0];
    return {
        name: item.name,
        isAuspicious: item.isAuspicious,
        type: item.isAuspicious ? "Hoàng Đạo" : "Hắc Đạo"
    };
}

function getFestival(lunarDay, lunarMonth, isLeap, isEn) {
    if (isLeap) return "";
    if (lunarMonth === 1) {
        if (lunarDay === 1) return isEn ? "Lunar New Year (Tet)" : "Tết Nguyên Đán";
        if (lunarDay === 2) return isEn ? "2nd Day of Tet" : "Mùng 2 Tết";
        if (lunarDay === 3) return isEn ? "3rd Day of Tet" : "Mùng 3 Tết";
        if (lunarDay === 15) return isEn ? "Lantern Festival" : "Rằm Tháng Giêng (Tết Nguyên Tiêu)";
    } else if (lunarMonth === 3) {
        if (lunarDay === 3) return isEn ? "Cold Food Festival" : "Tết Hàn Thực";
        if (lunarDay === 10) return isEn ? "Hung Kings Commemoration" : "Giỗ Tổ Hùng Vương";
    } else if (lunarMonth === 4) {
        if (lunarDay === 15) return isEn ? "Buddha Birthday" : "Lễ Phật Đản";
    } else if (lunarMonth === 5) {
        if (lunarDay === 5) return isEn ? "Mid-year Festival (Doan Ngo)" : "Tết Đoan Ngọ";
    } else if (lunarMonth === 7) {
        if (lunarDay === 7) return isEn ? "Double Seventh (That Tich)" : "Lễ Thất Tịch";
        if (lunarDay === 15) return isEn ? "Ghost Festival / Vu Lan" : "Lễ Vu Lan (Rằm Tháng Bảy)";
    } else if (lunarMonth === 8) {
        if (lunarDay === 15) return isEn ? "Mid-Autumn Festival" : "Tết Trung Thu";
    } else if (lunarMonth === 9) {
        if (lunarDay === 9) return isEn ? "Double Ninth Festival" : "Tết Trùng Cửu";
    } else if (lunarMonth === 10) {
        if (lunarDay === 10) return isEn ? "Double Tenth Festival" : "Tết Trùng Thập";
        if (lunarDay === 15) return isEn ? "Lower Yuan Festival" : "Tết Hạ Nguyên";
    } else if (lunarMonth === 12) {
        if (lunarDay === 23) return isEn ? "Kitchen Gods Day" : "Ông Táo Chầu Trời";
        if (lunarDay === 29 || lunarDay === 30) return isEn ? "New Year's Eve" : "Đêm Giao Thừa (Tất Niên)";
    }
    return "";
}

function getMoonPhase(lunarDay) {
    if (lunarDay === 1 || lunarDay === 30) {
        return { name: "Trăng non (Sóc)", icon: "󰽢", phase: 0 };
    } else if (lunarDay >= 2 && lunarDay <= 6) {
        return { name: "Trăng lưỡi liềm đầu tháng", icon: "󰽣", phase: 1 };
    } else if (lunarDay >= 7 && lunarDay <= 9) {
        return { name: "Thượng huyền", icon: "󰽤", phase: 2 };
    } else if (lunarDay >= 10 && lunarDay <= 14) {
        return { name: "Trăng trương đầu tháng", icon: "󰽥", phase: 3 };
    } else if (lunarDay === 15 || lunarDay === 16) {
        return { name: "Trăng tròn (Rằm / Vọng)", icon: "󰽡", phase: 4 };
    } else if (lunarDay >= 17 && lunarDay <= 21) {
        return { name: "Trăng trương cuối tháng", icon: "󰽦", phase: 5 };
    } else if (lunarDay >= 22 && lunarDay <= 24) {
        return { name: "Hạ huyền", icon: "󰽧", phase: 6 };
    } else {
        return { name: "Trăng lưỡi liềm cuối tháng", icon: "󰽨", phase: 7 };
    }
}

function getMonthName(lunarMonth, isLeap, isEn) {
    let name = isEn ? MONTH_NAMES_EN[lunarMonth - 1] : MONTH_NAMES_VI[lunarMonth - 1];
    if (isLeap) {
        name += isEn ? " (Leap)" : " (Nhuận)";
    }
    return name;
}

function getFullDetails(dateObj, isEn, timeZone) {
    let d = dateObj || new Date();
    let dd = d.getDate();
    let mm = d.getMonth() + 1;
    let yy = d.getFullYear();
    let hh = d.getHours();

    let lunar = solar2lunar(dd, mm, yy, timeZone);
    let canChiYear = getCanChiYear(lunar.year);
    let canChiMonth = getCanChiMonth(lunar.month, lunar.year);
    let canChiDay = getCanChiDay(lunar.jd);
    let canChiHour = getCanChiHour(hh, lunar.jd);
    let animal = getAnimalYear(lunar.year, isEn);
    let monthName = getMonthName(lunar.month, lunar.leap, isEn);
    let solarTerm = getSolarTerm(lunar.jd, isEn, timeZone);
    let zodiacHours = getZodiacHours(lunar.jd);
    let zodiacHoursShort = getZodiacHoursShort(lunar.jd);
    let dayZodiac = getDayZodiac(lunar.month, lunar.jd);
    let festival = getFestival(lunar.day, lunar.month, lunar.leap, isEn);
    let moon = getMoonPhase(lunar.day);

    let dayStr = "";
    if (lunar.day === 1) {
        dayStr = isEn ? "1st" : "Mùng 1";
    } else if (lunar.day === 15) {
        dayStr = isEn ? "15th (Full Moon)" : "Rằm (15)";
    } else {
        dayStr = isEn ? `${lunar.day}th` : `Mùng ${lunar.day}`;
        if (lunar.day >= 10 && !isEn) {
            dayStr = `Ngày ${lunar.day}`;
        }
    }

    return {
        solarDay: dd,
        solarMonth: mm,
        solarYear: yy,
        lunarDay: lunar.day,
        lunarMonth: lunar.month,
        lunarYear: lunar.year,
        isLeap: lunar.leap,
        jd: lunar.jd,
        dayStr: dayStr,
        monthName: monthName,
        canChiYear: canChiYear,
        canChiMonth: canChiMonth,
        canChiDay: canChiDay,
        canChiHour: canChiHour,
        animal: animal,
        solarTerm: solarTerm,
        zodiacHours: zodiacHours,
        zodiacHoursShort: zodiacHoursShort,
        dayZodiac: dayZodiac,
        festival: festival,
        moon: moon
    };
}
