#!/bin/bash
# Usage: curl -fsSL https://raw.githubusercontent.com/Norbert515/vide_cli/main/scripts/install.sh | bash

set -e

REPO="Norbert515/vide_cli"
INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="vide"

# Detect OS and architecture
detect_platform() {
    local os=$(uname -s)
    local arch=$(uname -m)

    case "$os" in
        Darwin)
            # macOS - use universal binary
            echo "macos"
            ;;
        Linux)
            case "$arch" in
                x86_64)
                    echo "linux-x64"
                    ;;
                *)
                    echo "Unsupported architecture: $arch" >&2
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Unsupported operating system: $os" >&2
            exit 1
            ;;
    esac
}

# Fetch latest version from GitHub API
get_latest_version() {
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name":' | \
        sed -E 's/.*"v([^"]+)".*/\1/'
}

main() {
    echo "Installing vide..."

    # Detect platform
    local platform=$(detect_platform)
    echo "Detected platform: $platform"

    # Get latest version
    echo "Fetching latest version..."
    local version=$(get_latest_version)
    if [ -z "$version" ]; then
        echo "Failed to fetch latest version" >&2
        exit 1
    fi
    echo "Latest version: $version"

    # Determine binary name based on platform
    local binary_file="vide-$platform"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download binary
    local download_url="https://github.com/$REPO/releases/download/v$version/$binary_file"
    echo "Downloading from: $download_url"
    curl -fsSL "$download_url" -o "$INSTALL_DIR/$BINARY_NAME"

    # Make executable
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    echo ""
    echo "Successfully installed vide $version to $INSTALL_DIR/$BINARY_NAME"

    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo ""
        echo "WARNING: $INSTALL_DIR is not in your PATH"
        echo ""
        echo "Add it to your shell configuration:"
        echo ""
        echo "  For bash (~/.bashrc or ~/.bash_profile):"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "  For zsh (~/.zshrc):"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    fi

    echo ""
    echo "Run 'vide --help' to get started"
}

main
