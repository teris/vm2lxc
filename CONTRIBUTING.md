# Contributing / Mitwirken

Pull requests are welcome for Bash implementation, translated strings and Proxmox test scenarios.

1. Open an issue describing the problem and your Proxmox VE version.
2. Provide reproducible mock tests for bug fixes. Never include private VM archives, credentials or host logs.
3. Run `bash -n bin/pve-vm2lxc lib/*.sh` and `for t in tests/test-*.sh; do bash "$t" || exit 1; done`.
4. Do not introduce a Python or other language runtime dependency for the migration tool.
5. Keep source VMs intact, block simultaneous duplicate IP/MAC use, and clean up only resources owned by the current run.
6. Maintain German and English UI text for all new screens. Document Proxmox-only integration cases separately.

Community reports should scrub real IP addresses, hostnames, authentication material and file paths with identifying contents.
