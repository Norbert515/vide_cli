

default:
    @just --list

# Install vide globally (native compiled)
install: compile
    mkdir -p ~/.vide/bin
    mkdir -p ~/.local/bin
    cp vide ~/.vide/bin/vide
    codesign -s - ~/.vide/bin/vide
    cp scripts/vide-wrapper.sh ~/.local/bin/vide
    chmod +x ~/.local/bin/vide

# Compile locally (for testing)
compile:
    dart pub get
    dart compile exe bin/vide.dart -o vide

# Generate bundled devtools code (run after changing runtime_ai_dev_tools)
generate-devtools:
    dart run packages/flutter_runtime_mcp/tool/generate_bundled_devtools.dart

# Run vide as if it's the first time (shows onboarding)
test-onboarding:
    VIDE_FORCE_WELCOME=1 dart run bin/vide.dart

# Create a new release (interactive)
release:
    #!/usr/bin/env bash
    set -euo pipefail

    # Get the latest tag
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
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
