#!/bin/bash
set -e

echo "Running tests with coverage..."
dart test --coverage=coverage --exclude-tags e2e

echo "Formatting coverage..."
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib

echo "Coverage report generated at coverage/lcov.info"

# Generate HTML report if genhtml is available
if command -v genhtml &> /dev/null; then
  echo "Generating HTML report..."
  genhtml coverage/lcov.info -o coverage/html
  echo "HTML report: coverage/html/index.html"
else
  echo "Note: Install lcov to generate HTML reports (brew install lcov)"
fi
