#pragma once

#include <esp_system.h>

#include <cstdint>

// Stub for CrumBLE's silent-restart OOM recovery system.
// Without the full CrumBLE infrastructure, we fall back to ESP.restart().
// The dictionary features work fine without this — it's only used as a
// last-resort recovery when heap is critically low during lookup.

enum class ReaderPostBootAction : uint8_t { None = 0 };

inline void silentRestart() { ESP.restart(); }

inline void silentRestartToReader() { ESP.restart(); }

inline void silentRestartToFileTransfer() { ESP.restart(); }

inline void silentRestartToReaderWithDefinition(const char* word) {
  (void)word;
  ESP.restart();
}

inline void silentRestartToReaderWithCursorWord(const char* word) {
  (void)word;
  ESP.restart();
}

inline void silentRestartToReaderResumingAtSpine(int targetSpine) {
  (void)targetSpine;
  ESP.restart();
}

inline void silentRestartToReaderWithAction(ReaderPostBootAction action) {
  (void)action;
  ESP.restart();
}

inline void silentRestartToOtaUpdate() { ESP.restart(); }

inline void silentRestartToBluetoothSettings() { ESP.restart(); }

inline void silentRestartToKoreaderAuth() { ESP.restart(); }

inline void silentRestartToOpdsBrowser() { ESP.restart(); }

inline bool isContinuingFromSilentReboot() { return false; }

inline void clearSilentRebootContinuationFlag() {}
