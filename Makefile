# Makefile for dev-images — builds udi-tools base + derivatives
# Modeled on bootc-images/Makefile
# Supports both podman (local dev) and docker (CI via CONTAINER_TOOL=docker)

REGISTRY ?= localhost
TAG ?= latest
CONTAINER_TOOL ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)

IMAGES := udi-tools udi-tools-claude

.PHONY: build-all lint push-all clean

# ── Build targets ──────────────────────────────────────────────

build-udi-tools:
	$(CONTAINER_TOOL) build -t $(REGISTRY)/udi-tools:$(TAG) -f images/udi-tools/Containerfile .

build-udi-tools-claude: build-udi-tools
	$(CONTAINER_TOOL) build -t $(REGISTRY)/udi-tools-claude:$(TAG) -f images/udi-tools-claude/Containerfile .

build-all: build-udi-tools build-udi-tools-claude

# ── Lint ───────────────────────────────────────────────────────

lint:
	@for cf in images/*/Containerfile; do \
		echo "==> hadolint $$cf"; \
		$(CONTAINER_TOOL) run --rm -i docker.io/hadolint/hadolint:stable < "$$cf" || exit 1; \
	done

# ── Push targets ───────────────────────────────────────────────

push-udi-tools:
ifndef REGISTRY
	$(error REGISTRY is required to push images. Set REGISTRY=ghcr.io/mattr7m)
endif
	$(CONTAINER_TOOL) tag $(REGISTRY)/udi-tools:$(TAG) $(REGISTRY)/udi-tools:latest || true
	$(CONTAINER_TOOL) push $(REGISTRY)/udi-tools:$(TAG) || true
	$(CONTAINER_TOOL) push $(REGISTRY)/udi-tools:latest || true

push-udi-tools-claude:
ifndef REGISTRY
	$(error REGISTRY is required to push images. Set REGISTRY=ghcr.io/mattr7m)
endif
	$(CONTAINER_TOOL) tag $(REGISTRY)/udi-tools-claude:$(TAG) $(REGISTRY)/udi-tools-claude:latest || true
	$(CONTAINER_TOOL) push $(REGISTRY)/udi-tools-claude:$(TAG) || true
	$(CONTAINER_TOOL) push $(REGISTRY)/udi-tools-claude:latest || true

push-all: push-udi-tools push-udi-tools-claude

# ── Clean ──────────────────────────────────────────────────────

clean:
	$(CONTAINER_TOOL) rmi $(foreach img,$(IMAGES),$(REGISTRY)/$(img):$(TAG)) 2>/dev/null || true
	$(CONTAINER_TOOL) rmi $(foreach img,$(IMAGES),$(REGISTRY)/$(img):latest) 2>/dev/null || true
