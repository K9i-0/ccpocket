#!/usr/bin/env bash
# The one place the Quint version is pinned. Every script under formal/ calls this.
exec npx -y @informalsystems/quint@0.34.0 "$@"
