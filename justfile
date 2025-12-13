

default:
    @just --list

# Install vide globally (native compiled)
install: compile
    cp vide ~/.pub-cache/bin/vide

# Compile locally (for testing)
compile:
    dart pub get
    dart compile exe bin/vide.dart -o vide
