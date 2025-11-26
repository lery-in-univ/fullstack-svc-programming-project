#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Dart language server 이미지 빌드
docker build -t dart-lsp:3.9.4 -f "$SCRIPT_DIR/dart-lsp/Dockerfile" "$SCRIPT_DIR/dart-lsp"
