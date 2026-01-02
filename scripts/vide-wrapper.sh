#!/bin/bash
VIDE_HOME="$HOME/.vide"
VIDE_BIN="$VIDE_HOME/bin/vide"
PENDING_UPDATE="$VIDE_HOME/updates/pending/vide"
PENDING_META="$VIDE_HOME/updates/pending/metadata.json"

# Apply pending update if exists
if [ -f "$PENDING_UPDATE" ]; then
    mv "$PENDING_UPDATE" "$VIDE_BIN"
    chmod +x "$VIDE_BIN"
    rm -f "$PENDING_META"
fi

exec "$VIDE_BIN" "$@"
