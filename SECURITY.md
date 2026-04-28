# Security Policy

## Supported Version

Only the current public script is maintained through the default download entry:

```text
https://nradio.mayebano.shop/ssh-nradio-plugin-installer.sh
```

Historical files in `00-current/` may be kept for reference, but they are not the default support target.

## Reporting

If you find a security issue, open a GitHub issue only with non-sensitive reproduction details.

Do not publish:

- router root passwords
- SSH public IP or private tunnel credentials
- cookies or session files
- complete VPN profiles containing real keys
- full backups from a live router

For a safe report, include:

- device model
- NROS firmware version
- script version
- affected menu path
- minimal sanitized log output

## Scope

This project is a public helper script for NRadio official NROS devices. It does not provide support for standard OpenWrt devices or unrelated routers.

