#ifdef SIMULATOR

#include "SimulatorSmokeTest.h"

#include <Logging.h>

// Smoke test disabled — upstream API does not match this fork.
// Re-enable once MappedInputManager gains simulatorInject* methods,
// CrossPointSettings gains the migration contract checks, and
// ActivityManager::goToReader signature matches.
void runSimulatorSmokeTestTick() {}

#endif
