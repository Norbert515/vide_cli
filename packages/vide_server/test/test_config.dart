/// Shared test configuration for vide_server integration tests
library;

/// Base port for integration tests.
/// Each test file should use a unique offset from this base to avoid conflicts.
const int testPortBase = 18080;

/// Port offsets for different test files
const int endToEndTestOffset = 0;
const int streamingTurnsTestOffset = 2;
