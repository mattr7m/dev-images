# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Container images for Red Hat Devspaces / Eclipse Che CDE platform. Uses a base/derivative pattern — `images/udi-tools/Containerfile` extends the Red Hat Universal Developer Image (UBI9) with additional CLI tools and utilities.

## Build

Build the base image with podman or docker:

```bash
podman build -t udi-tools -f images/udi-tools/Containerfile .
```

The build context must be the repo root (not `images/udi-tools/`) because the Containerfile copies files from `scripts/`.

### devbox (kubeopencode-oriented)

```bash
podman build -t devbox -f images/devbox/Containerfile .
```

Build the derivative after the base:

```bash
podman build -t udi-tools-claude -f images/udi-tools-claude/Containerfile .
```

The build context must be the repo root (not `images/devbox/`) because the Containerfile references files at the top level.

## Architecture

- **`images/udi-tools/Containerfile`** — Main artifact. Installs CLI tools (argocd, gh, roxctl, kubeseal, kustomize, kubecolor, yq, colordiff, ansible) and the VSCode tunnel CLI on top of the UBI9 base image. Tool versions are pinned via `ARG` directives at the top of the file.
- **`scripts/tunnel-log-watch.py`** — Python script (copied into the image) that monitors VSCode tunnel logs for authentication codes and emails them to the developer. Requires `DEV_EMAIL`, `START_DEV_TUNNEL`, and `DEVWORKSPACE_NAME` environment variables.
- **`scripts/requirements.txt`** — Python dependencies for tunnel-log-watch (watchdog, requests).

## Conventions

- When adding a new CLI tool, follow the existing pattern: pin the version in an `ARG`, download the binary handling architecture detection (`x86_64`→`amd64`), install to `/usr/local/bin`, and clean up temp files.
- The image runs as `USER 0` (root) during build, then uses `/home/user` as `HOME` at runtime.
