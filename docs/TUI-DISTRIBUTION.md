# TUI distribution (v0.3.0)

The shipped UI is a **pure-Bash, ANSI-based full-screen terminal interface**. It does not require a compiled executable, Gum, Go, Bubble Tea or dialog. It is intentionally simpler than btop or a Bubble Tea UI: no mouse input, live resource graphs or background job manager yet.

A compiled Bubble Tea frontend remains a possible future enhancement. If implemented later, releases must bundle its native binary and document a source build path and third-party dependency licenses.

The `legacy-plan` mode still uses dialog and has extra dependencies, documented in README.md.
