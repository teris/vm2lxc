# Security

Do not put host logs, migration archives, SSH keys or stored profiles into GitHub issues or pull requests.

This project runs with Proxmox host administrative privileges. Review the migration plan, source shutdown, target CT ID, network and storage configuration before approving a conversion. The tool does not promise a lossless conversion of file ownership, ACLs, kernel features or device passthrough. Use disposable test guests and backups for testing.

Report security concerns privately to repository maintainers once a public GitHub repository and contact policy have been established.
