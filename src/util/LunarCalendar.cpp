#include "LunarCalendar.h"

#include <cmath>
#include <cstdlib>

namespace {

// Julian day number from Gregorian date (dd/mm/yyyy)
int jdFromDate(int dd, int mm, int yy) {
  int a = (14 - mm) / 12;
  int y = yy + 4800 - a;
  int m = mm + 12 * a - 3;
  return dd + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045;
}

// Sun longitude in degrees (AA98 algorithm)
double sunLongitudeAA98(double jdn) {
  double T = (jdn - 2451545.0) / 36525.0;
  double L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
  double M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T;
  double Mrad = M * M_PI / 180.0;
  double C = (1.9146 - 0.004817 * T - 0.000014 * T * T) * sin(Mrad) + (0.019993 - 0.000101 * T) * sin(2.0 * Mrad) +
             0.00029 * sin(3.0 * Mrad);
  double sunLong = L0 + C;
  sunLong -= 360.0 * floor(sunLong / 360.0);
  return sunLong;
}

double sunLongitude(double jdn) { return sunLongitudeAA98(jdn); }

// New moon day (Julian day number) for k-th new moon after epoch
int newMoonDay(int k, double timeZone) {
  double T = k / 1236.85;
  double T2 = T * T;
  double T3 = T2 * T;
  double dr = M_PI / 180.0;
  double Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3;
  Jd1 += 0.00033 * sin((166.56 + 132.87 * T - 0.009173 * T2) * dr);
  double M = 359.2242 + 29.10535670 * k - 0.0000014 * T2 - 0.00000011 * T3;
  double Mrad = M * dr;
  double m0 = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3;
  double m1 = 201.5643 + 390.67050646 * k - 0.0016118 * T2 - 0.00000227 * T3;
  double i1 = (1 - 0.0020954 * T2) * (0.1728 * sin(Mrad) - 0.0003 * sin(3.0 * Mrad));
  double i2 = 0.0020954 * T2 * 0.001 * sin(3.0 * Mrad);
  double conj = Jd1 + i1 + i2;
  double F = 0.5 + 0.5 * sin((m0 + m1) * dr) / sin((0.0020954 * T2 + 1.0) * dr);

  double phase = sunLongitude(conj);
  double jdn = conj - F + 0.5 + timeZone / 24.0;
  jdn = floor(jdn);
  return static_cast<int>(jdn);
}

// Get lunar month 11 of a given year
int getLunarMonth11(int yy, double timeZone) {
  int off = jdFromDate(31, 12, yy) - 2415021;
  int k = static_cast<int>(floor(static_cast<double>(off) / 29.530588853));
  int nm = newMoonDay(k + 1, timeZone);
  int sunLong = static_cast<int>(sunLongitude(static_cast<double>(nm)));
  if (sunLong >= 270) {
    nm = newMoonDay(k, timeZone);
  }
  return nm;
}

// Get leap month offset for a year
int getLeapMonthOffset(int a11, double timeZone) {
  int k = static_cast<int>(floor(0.5 + (a11 - 2415021.076998695) / 29.530588853));
  int last = 0;
  int i = 1;
  int arc = static_cast<int>(sunLongitude(static_cast<double>(newMoonDay(k + i, timeZone))));
  do {
    last = arc;
    i++;
    arc = static_cast<int>(sunLongitude(static_cast<double>(newMoonDay(k + i, timeZone))));
  } while (arc != last && i < 14);
  return i - 1;
}

}  // namespace

LunarDate solarToLunar(int day, int month, int year, double timeZone) {
  int dayNumber = jdFromDate(day, month, year);
  int k = static_cast<int>(floor(static_cast<double>(dayNumber - 2415021.076998695) / 29.530588853));
  int monthStart = newMoonDay(k + 1, timeZone);
  if (monthStart > dayNumber) {
    monthStart = newMoonDay(k, timeZone);
  }
  int a11 = getLunarMonth11(year, timeZone);
  int b11;
  int lunarYear;

  if (a11 >= monthStart) {
    lunarYear = year;
    a11 = getLunarMonth11(year - 1, timeZone);
  } else {
    lunarYear = year + 1;
  }
  b11 = getLunarMonth11(lunarYear + 1, timeZone);

  int lunarDay = dayNumber - monthStart + 1;
  int diff = static_cast<int>(floor(static_cast<double>(monthStart - a11) / 29.0));
  int lunarLeap = 0;
  int lunarMonth = diff + 11;

  if (b11 - a11 > 365) {
    int leapMonthDiff = getLeapMonthOffset(a11, timeZone);
    if (diff >= leapMonthDiff) {
      lunarMonth = diff + 10;
      if (diff == leapMonthDiff) {
        lunarLeap = 1;
      }
    }
  }

  if (lunarMonth > 12) {
    lunarMonth -= 12;
  }
  if (lunarMonth >= 11 && diff < 4) {
    lunarYear -= 1;
  }

  return {lunarDay, lunarMonth, lunarYear, lunarLeap == 1};
}
