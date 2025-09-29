# Docker Mailserver

A production-ready, containerized mail server stack built with Docker Compose. It provides a complete SMTP, IMAP/LMTP, Sieve filtering, DKIM signing, spam/virus filtering, TLS, and user management solution using:

- **Postfix**: SMTP relay, submission, and LMTP to Dovecot
- **Dovecot**: IMAP/LMTP server with Sieve, quota, and mailbox management
- **Rspamd**: Spam filtering, DKIM signing, RBLs, Bayes classifier
- **ClamAV**: Antivirus scanning via Rspamd integration
- **ACME Companion**: Automated certificate acquisition/renewal (e.g., Let's Encrypt) for CloudFlare DNS API

The stack is intended to be self-hosted and runs as multiple containers defined in `docker-compose.yml`. Persistent state lives under `data/`.
## Features

- **SMTP/IMAP** with STARTTLS/TLS
- **Authentication** via Dovecot
- **Sieve** filtering for spam and automatic foldering
- **DKIM** signing on outbound mail (Rspamd)
- **Spam filtering** with Rspamd (Bayes, RBLs, metrics, milter headers)
- **Antivirus** scanning (ClamAV)
- **Automatic certificates** via ACME
- **Config-as-code**: declarative config in `docker/` and persistent runtime data in `data/`
## Repository Layout

```text
docker-mailserver/
	docker/ # Dockerfiles and container rootfs overlays per service
		postfix/
		dovecot/
		filter/ # Rspamd
		virus/ # ClamAV
		acme/
	data/ # Persistent state and mounted configs
		certs/ # SSL cetrificates needed for Postifx and Dovecot
		postfix/maps/ # postfix related maps like virtual aliases, etc
		filter/dkim/ # DKIM key for DKIM signing
		maildir/ # there real mailboxes live
	docker-compose.yml
	scripts/
		user-manager.sh # Helpers for user management
	setup.sh # Project setup bootstrap
```
## Prerequisites

- Docker and Docker Compose installed
- A domain with DNS records you control
- Ability to open the following ports on your host/firewall:
- 25/tcp (SMTP) – required for incoming mail from other MTAs
- 465/tcp (SMTPS) – optional, if enabled
- 587/tcp (Submission) – for client outbound mail with auth
- 993/tcp (IMAPS) – IMAP over TLS for clients
- 11334/tcp (Rspamd controller, optional/admin)
## DNS Records

Set DNS for your domain (replace `mail.example.com` and `example.com`):
- **A/AAAA**: `mail.example.com` → your server IP
- **MX**: `example.com` → `mail.example.com` (priority 10)
- **SPF (TXT)**: e.g. `v=spf1 mx -all`
- **DKIM (TXT)**: publish the selector from `data/filter/dkim/mail.pub` (will be generated after first start)
- **DMARC (TXT)**: e.g. `_dmarc.example.com IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"`
- **PTR**/rDNS for your server IP → `mail.example.com`
## Quick Start
1. Clone and configure environment
```bash
git clone <this-repo-url> docker-mailserver
cd docker-mailserver
# Review and edit docker-compose.yml and files in docker/* if needed
```
1. Run `setup.sh` to prepare `.env` and fulfils it with your values
2. Generate strong `dhparams.pem` with command: 
   `openssl dhparam -out ./data/certs/dhparams.pem 4096`
3. Build docker images:
   ```bash
   docker compose build acme
   docker compose build acme-init
   ```
4. Generate LetsEncrypt SSL Ceritficate:
   `docker compose --profile init up acme-init`
5. Bring up the stack
   `docker compose up -d`
6. Create users and mailboxes:
```bash
./scripts/user-manager.sh add user@example.com
./scripts/user-manager.sh passwd user@example.com
```
7. Configure your mail client:
- Incoming IMAP (IMAPS): `mail.example.com`, port 993, TLS, login: full email address
- Outgoing SMTP (Submission): `mail.example.com`, port 587, STARTTLS, login: full email address
## Services and Configuration
### Postfix

- Config files shipped under `docker/postfix/rootfs/etc/postfix/`
- Persistent maps and additional runtime files under `data/postfix/`
- Customize maps in `data/postfix/maps/` (e.g., `virtual_alias_maps`, `access`, etc.)
### Dovecot

- Config under `docker/dovecot/rootfs/etc/dovecot/`
- Sieve scripts under `docker/dovecot/rootfs/etc/dovecot/sieve/`
- Mail storage under `data/maildir/`
### Rspamd (Spam Filter & DKIM)

- Config under `docker/filter/rootfs/etc/rspamd/`
- DKIM keys under `data/filter/dkim/`
- Key selector and domain must match your DNS TXT DKIM record
### ClamAV (Antivirus)

- Config under `docker/virus/rootfs/etc/clamav/`
- Integrated via Rspamd antivirus module
### Certificates (ACME)

- ACME container places/renews certs in `data/certs/`
## Data Persistence

All persistent runtime data is stored under `data/` and mounted into containers:
- `data/maildir/` – user mailboxes
- `data/certs/` – TLS certificates
- `data/filter/dkim/` – DKIM keys
- `data/postfix/` – maps and runtime postfix data

Back up `data/` regularly.
## User Management

Use the helper script in `scripts/user-manager.sh`:

```bash
# Add a user
./scripts/user-manager.sh add user@example.com

# Change password
./scripts/user-manager.sh passwd user@example.com

# Remove a user
./scripts/user-manager.sh del user@example.com

```

Mailboxes are stored under `data/maildir/`.
## Building and Running

```bash
# Build all images
docker compose build

# Start services
docker compose up -d

# View logs for a specific service (e.g., postfix)
docker compose logs -f postfix | cat

# Stop services
docker compose down
```
## DKIM Setup

1. Ensure Rspamd DKIM signing is enabled (see `docker/filter/rootfs/etc/rspamd/local.d/dkim_signing.conf`).
2. Generate DKIM keys if not present and place them into `data/filter/dkim/`.
3. Publish the DKIM public key in DNS under your chosen selector.
4. Reload filter/postfix services if needed.
```bash
docker compose exec filter /usr/local/bin/entrypoint.sh reload
docker compose exec postfix /usr/local/bin/entrypoint.sh reload
```
## Sieve Filtering

Global Sieve scripts live under `docker/dovecot/rootfs/etc/dovecot/sieve/global/` (e.g., spam learning, spam-to-folder). Users can enable per-user rules via their mail clients or by providing user-specific Sieve scripts.
## Backups

- Back up `data/` periodically (rsync, snapshots, etc.).
- Test restores in a staging environment.
## Troubleshooting

- Check service logs:
```bash
docker compose logs --tail=200 postfix | cat
docker compose logs --tail=200 dovecot | cat
docker compose logs --tail=200 filter | cat
docker compose logs --tail=200 virus | cat
docker compose logs --tail=200 acme | cat
```
- Verify ports are listening on the host and inside containers
- Validate DNS (MX, SPF, DKIM, DMARC) with external tools
- Ensure rDNS/PTR matches your mail hostname to improve deliverability
## Security Notes

- Use strong passwords for all users
- Limit administrative interfaces (e.g., Rspamd controller) to trusted networks
- Keep images up to date: rebuild regularly to pull latest security updates
## Maintenance

```bash
# Update images and restart
docker compose pull
docker compose up -d

# Rebuild from Dockerfiles after changes
docker compose build --no-cache
docker compose up -d
```
## License

This project is provided under the MIT License.
## Credits

- Postfix, Dovecot, Rspamd, Acme.sh and ClamAV communities
- Inspired by common self-hosted mailserver stacks
- https://gitlab.com/argo-uln for initial ideas how to make mailserver setup with docker
