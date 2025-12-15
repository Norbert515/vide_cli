

default:
    @just --list

# Install vide globally (native compiled)
install: compile
    rm -f ~/.local/bin/vide
    cp vide ~/.local/bin/vide
    codesign -s - ~/.local/bin/vide

# Compile locally (for testing)
compile:
    dart pub get
    dart compile exe bin/vide.dart -o vide

# Generate bundled devtools code (run after changing runtime_ai_dev_tools)
generate-devtools:
    dart run packages/flutter_runtime_mcp/tool/generate_bundled_devtools.dart
