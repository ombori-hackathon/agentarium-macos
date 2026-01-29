.PHONY: build run test lint format install-hooks clean help

# Default target
help:
	@echo "Available commands:"
	@echo "  make build         - Build the project"
	@echo "  make run           - Build and run the app"
	@echo "  make test          - Run tests"
	@echo "  make lint          - Check code formatting"
	@echo "  make format        - Auto-format code"
	@echo "  make install-hooks - Install git pre-commit hooks"
	@echo "  make clean         - Clean build artifacts"

build:
	swift build

run:
	swift run AgentariumClient

test:
	@echo "Tests require full Xcode installation (XCTest not available with CLT only)"
	@echo "Install Xcode from App Store, then uncomment testTarget in Package.swift"

lint:
	swift format lint --strict --recursive Sources/

format:
	swift format --in-place --recursive Sources/

install-hooks:
	@echo "Installing pre-commit hook..."
	@chmod +x scripts/pre-commit
	@HOOKS_DIR=$$(git rev-parse --git-dir)/hooks; \
	cp scripts/pre-commit "$$HOOKS_DIR/pre-commit"; \
	chmod +x "$$HOOKS_DIR/pre-commit"; \
	echo "Pre-commit hook installed to $$HOOKS_DIR/pre-commit"

clean:
	swift package clean
	rm -rf .build
