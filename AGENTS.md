# Repository Guidelines

## Project Structure & Module Organization
- Core VM and tooling live at the repo root (e.g., `vm*.c`, `vm.h`, `tty.c`,
  `wrapper.c`, `functions/`).
- Bootstrap artifacts are organized by stage: `stage0/`, `stage1/`, `stage2/`,
  `stage3/`. Sources commonly use `.hex0`, `.hex1`, `.hex2`, and `.s`.
- Ports and platform work live in their own directories (e.g., `POSIX/`, `x86/`,
  `UEFI/`).
- Generated outputs: `bin/` (tools), `roms/` (built ROM images),
  `prototypes/` (prototype tools), and scratch under `test/`.

## Build, Test, and Development Commands
- `make all`: build the VM (`bin/vm`), `libvm.so`, ROM images, and prototypes.
- `make development` / `make production`: convenience targets for dev vs
  production-oriented builds.
- `make clean` / `make clean-hard`: remove generated artifacts (`bin/`, `roms/`,
  `prototypes/`, and test scratch).
- `make test`: verify ROM outputs against `test/SHA256SUMS`.
- `make test-all`: run the full verification suite (checksum + assembly and
  disassembly round-trips).
- `python3` is required for `make test-all` (runs `High_level_prototypes/disasm.py`).

## Coding Style & Naming Conventions
- C code uses tabs for indentation and braces on their own line; match nearby
  style and keep diffs small.
- Prefer descriptive names over abbreviations (e.g., `load_program`).
- Put new bootstrap-stage sources in the appropriate `stageN/` directory; put
  port-specific work under the relevant port directory.

## Testing Guidelines
- Keep tests deterministic: ROMs and round-trip checks must be bit-for-bit
  stable.
- Update `test/SHA256SUMS` only when a ROM change is intentional:
  `make Generate-rom-test` (then run `make test-all`).

## Commit & Pull Request Guidelines
- Commit messages in this repo are short, imperative, and specific (e.g., `Fix
  broken builds`, `Add support for anonymous enums`).
- PRs should include: what changed, why, how to reproduce, and the exact command
  run (typically `make test-all`). If a ROM changes, call it out explicitly and
  explain the checksum update.

## Submodules & Setup
- Clone with submodules: `git clone --recursive`.
- After pulling: `git submodule update --init --recursive`.
