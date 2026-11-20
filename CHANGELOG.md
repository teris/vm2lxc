# Changelog

## [1.0.0] - 2026-11-20

- Reworked terminal shortcuts: `Ctrl+R` one wizard step back, `Esc` restart, `Alt+R` refresh, `Ctrl+L` language, `Ctrl+D` confirmed profile deletion.
- Added non-secret wizard prompt history and safe replay without re-running the migration engine.
- Updated bilingual navigation labels, tooltips, and common assistant prompts.
- All diagnostic logs and temporary monitor/installer logs under the current checkout or installed project's `logs/` subdirectory.
- Kept direct `bash bin/pve-vm2lxc` execution and optional `/opt/pve-vm2lxc` installation; centralized version in `VERSION`.
- Added GitHub-ready README, .gitignore, MIT license, contribution instructions, and CI for Bash syntax/mock tests.
- Based on v0.6.11 migration engine and v0.6.9 fast ownership import. Known permission, mountpoint, and device limitations remain; validate on a test Proxmox host before production use.

See `docs/HISTORY.md` for archived development notes.
