

default:
    @just --list

# Install vide globally (native compiled)
install: compile
    mkdir -p ~/.vide/bin
    mkdir -p ~/.local/bin
    rm -rf ~/.vide/updates/pending/
    cp vide ~/.vide/bin/vide
    codesign -s - ~/.vide/bin/vide
    cp scripts/vide-wrapper.sh ~/.local/bin/vide
    chmod +x ~/.local/bin/vide

# Compile locally (for testing) - uses high version to prevent auto-update
compile:
    dart pub get
    dart compile exe bin/vide.dart -o vide -DVIDE_VERSION=99.0.0-dev

# Generate bundled devtools code (run after changing runtime_ai_dev_tools)
generate-devtools:
    dart run packages/flutter_runtime_mcp/tool/generate_bundled_devtools.dart

# Generate bundled team framework assets (run after changing team_framework assets)
generate-teams:
    dart run packages/vide_core/tool/generate_bundled_team_framework.dart

# Generate all bundled assets
generate: generate-devtools generate-teams

# Run vide as if it's the first time (shows onboarding)
test-onboarding:
    VIDE_FORCE_WELCOME=1 dart run bin/vide.dart

# Start the vide daemon server (default port 8080)
daemon port="8080":
    cd packages/vide_daemon && dart run bin/vide_daemon.dart --port {{port}}

# Start the daemon in debug mode with verbose logging
daemon-debug port="8080":
    cd packages/vide_daemon && dart run bin/vide_daemon.dart --port {{port}} --verbose

# Create a new release (interactive)
release:
    #!/usr/bin/env bash
    set -euo pipefail

    # Get the latest tag (by version sort, not by commit ancestry)
    latest_tag=$(git tag --list 'v*' --sort=-v:refname | head -1)
    if [[ -z "$latest_tag" ]]; then
        latest_tag="v0.0.0"
    fi
    echo "Current version: $latest_tag"

    # Parse version numbers (strip 'v' prefix)
    version=${latest_tag#v}
    IFS='.' read -r major minor patch <<< "$version"

    # Show options
    echo ""
    echo "Select release type:"
    echo "  1) patch    → v$major.$minor.$((patch + 1))"
    echo "  2) minor    → v$major.$((minor + 1)).0"
    echo "  3) major    → v$((major + 1)).0.0"
    echo "  4) override → $latest_tag (re-push existing tag)"
    echo "  5) cancel"
    echo ""

    read -p "Choice [1-5]: " choice

    case $choice in
        1) new_version="v$major.$minor.$((patch + 1))" ;;
        2) new_version="v$major.$((minor + 1)).0" ;;
        3) new_version="v$((major + 1)).0.0" ;;
        4) new_version="$latest_tag"; override=true ;;
        5) echo "Cancelled."; exit 0 ;;
        *) echo "Invalid choice."; exit 1 ;;
    esac

    echo ""

    if [[ "${override:-false}" == "true" ]]; then
        read -p "Delete and re-push tag $new_version? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            git tag -d "$new_version"
            git push origin --delete "$new_version"
            git tag "$new_version"
            git push origin "$new_version"
            echo "✓ Re-released $new_version"
        else
            echo "Cancelled."
        fi
    else
        read -p "Create and push tag $new_version? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            git tag "$new_version"
            git push origin "$new_version"
            echo "✓ Released $new_version"
        else
            echo "Cancelled."
        fi
    fi
