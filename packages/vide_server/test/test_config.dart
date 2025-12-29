/// Shared test configuration for vide_server integration tests
library;

/// Base port for integration tests.
/// Each test file should use a unique offset from this base to avoid conflicts.
/// Using port 0 would be ideal (auto-select), but parsing port from output is complex.
/// Instead, we use large offsets to minimize collision risk.
const int testPortBase = 18080;

/// Port offsets for different test files.
/// Use large offsets (100+) to avoid port reuse issues when tests run in parallel.
const int endToEndTestOffset = 0;
const int streamingTurnsTestOffset = 100;
