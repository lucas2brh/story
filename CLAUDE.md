# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Story consensus client — Golang consensus layer for Story L1 blockchain. Uses **CECS** (Consensus Execution Client Separation) architecture inspired by Ethereum PoS:
- **Consensus Layer (CL)**: This repo — CometBFT-based Cosmos SDK app
- **Execution Layer (EL)**: story-geth — Ethereum-compatible execution client
- Communication via **Engine API** with JWT authentication

## Build & Development Commands

```bash
make build              # Build binary → build/story
make mod                # go mod tidy
make contract-bindings  # Generate Go bindings from Solidity contracts
make bufgen             # Generate protobuf code (requires buf)
make fix-golden         # Fix golden test fixtures
make install-go-tools   # Install dev tools (buf, etc.)
```

### Testing

```bash
# All Go tests with race detection
go test -timeout=5m -race -tags=verify_logs ./...

# Single package
go test ./client/x/evmstaking/keeper/...

# With coverage (CI command)
go test -coverprofile=coverage.txt -timeout=5m -race -tags=verify_logs ./...

# Contract tests (Foundry)
cd contracts && make test
```

### Linting

```bash
# Run golangci-lint (v1.59.1, config in .golangci.yml)
golangci-lint run
```

## Architecture

### Entry Point

`client/main.go` → `client/cmd/` (CLI commands: init, run, status, validator, keys, rollback)

### Custom Cosmos Modules (`client/x/`)

- **evmengine** — EL-CL bridge via Engine API. Handles block proposals (`PrepareProposal`/`ProcessProposal`), payload validation, upgrade processing, and optimistic block building (`PostFinalize`).
- **evmstaking** — Staking logic with two-queue withdrawal system (stake withdrawals + reward withdrawals, max 16 each per block). Processes EVM log events from IPTokenStaking contract (CreateValidator, Deposit, Withdraw, Redelegate, Unjail, etc.).
- **mint** — Custom mint module (modified from Cosmos SDK standard).

### Block Execution Flow

PreBlocker (upgrades) → BeginBlocker (mint→distribution→slashing→evidence→staking) → PrepareProposal → ProcessProposal → FinalizeBlock → PostFinalize (optimistic next block) → EndBlocker (gov→evmstaking, evmstaking must run before staking removes mature unbonding)

### Shared Libraries (`lib/`)

- `ethclient/` — go-ethereum client wrapper for Engine API
- `netconf/` — Network configs (iliad testnet, local dev)
- `errors/` — Custom error wrapping (use instead of `fmt.Errorf`)
- `log/` — Logging abstraction (use instead of stdlib `log`)
- `k1util/` — Secp256k1 utilities
- `buildinfo/` — Version info

### Smart Contracts (`contracts/`)

Foundry project with Solidity contracts: IPTokenStaking, UpgradeEntrypoint, UBIPool, Create3. Go bindings generated into `contracts/bindings/`.

## Code Conventions

### Import Order (enforced by gci)

stdlib → golang.org → cosmossdk.io → github.com → piplabs → story → default → blank

### Forbidden Imports

- `log` (stdlib) — use `lib/log`
- `github.com/gogo/protobuf/proto` — use `google.golang.org/protobuf/proto`
- `testify/assert` — use `testify/require`

### Generated Files (do not edit)

- `*.pb.go` — protobuf generated files
- `contracts/bindings/*` — Go bindings from Solidity

### Go Version

Go 1.22.11 (specified in go.mod)
