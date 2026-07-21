#pragma once
#include <ctime>

inline bool getLocalTime(struct tm* info, uint32_t /*ms*/ = 5000) {
  time_t now = time(nullptr);
  if (now < 0) return false;
  localtime_r(&now, info);
  return info->tm_year >= 125;
}

inline void configTzTime(const char* /*tz*/, const char* /*ntp1*/, const char* /*ntp2*/ = nullptr) {}

inline bool esp_sntp_enabled() { return false; }
