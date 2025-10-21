# Nextcloud Deployment with Docker Compose
This repository provides a Docker Compose configuration to deploy Nextcloud, a popular self-hosted cloud storage solution. The setup includes Nextcloud, a database (PostgreSQL), and a reverse proxy (traefik) for secure access.

## Prerequisites
- Docker and Docker Compose installed on your server.
- A domain name pointing to your server's IP address. This setup was completed without DNS records by adding entries to the `/etc/hosts` file.
- Basic knowledge of Docker and Docker Compose.

## Configuration

Put your root certificates authority (CA) files in the `./certs` directory. These files are used by Traefik for secure HTTPS connections.

Edit the .env file to set your environment variables:

```env
ROOTCA_PATH=./certs/ca.crt
NEXTCLOUD_SSLCERT=./certs/nextcloud.pem
NEXTCLOUD_SSLKEY=./certs/nextcloud.key
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=your_admin_password
```

## Certificate Trust

- All TLS assets live under `./certs`. The mkcert root CA is mounted into the application containers (Nextcloud, HPB, Harp, and Collabora) at `/usr/local/share/ca-certificates/mkcert-rootCA.crt` and exposed via the standard `SSL_CERT_FILE`, `CURL_CA_BUNDLE`, and `REQUESTS_CA_BUNDLE` environment variables (with sensible defaults provided in `docker-compose.yml`).
- Traefik serves certificates from `/etc/traefik/certs`. Static certificates are mapped explicitly in `traefik/dynamic/certs.yml`; you can add more by dropping the PEM/key pair into `./certs` and adding another entry to the file provider.
- To confirm a certificate chain quickly you can run `./certs/showcert.sh ./certs/<certificate>.pem` which prints issuer, SANs, and validity details.

## Extra Hosts

This stack relies on `extra_hosts` entries so that each container can resolve the development domains (e.g. `nextcloud-dev.lan`) back to the Docker host (Traefik listens on the host's 443/80). Defaults point to the Docker `host-gateway`, but you can override them in `.env`, for example:

```env
APP_EXTRA_HOST1=nextcloud-dev.lan:10.1.154.201
APP_EXTRA_HOST2=talk-dev.lan:10.1.154.201
APP_EXTRA_HOST3=collabora-dev.lan:10.1.154.201
```

### Talk High-performance Backend automation

At container start the `appapi-bootstrap.sh` helper installs/enables the Talk app and writes the High-performance backend settings via `occ`. Set `TALK_HOST`, `SIGNALING_SECRET`, and optionally `TURN_SECRET`/`TALK_PORT` in `.env` and the signaling, STUN, and TURN endpoints are registered automatically. Additional knobs (all optional) include:

- `TALK_SIGNALING_URL` (defaults to `https://${TALK_HOST}`)
- `TALK_VERIFY_TLS` (`true`/`false`, defaults to `true`)
- `TALK_STUN_SERVER` (defaults to `${TALK_HOST}:${TALK_PORT:-3478}`)
- `TALK_TURN_SERVER`, `TALK_TURN_SCHEMES`, `TALK_TURN_PROTOCOLS`
- `TALK_HIDE_WARNING` (suppresses the Talk admin warning when `true`)
- `TALK_HPB_ENABLE` (set to `false` to skip automatic HPB registration)

### Collabora Online bootstrap

The same bootstrap script now also provisions the Collabora Online integration so that collaborative editing works immediately after the first deploy. By default it installs/enables the `richdocuments` app, points it to the Collabora container (`COLLABORA_URL`, default `https://collabora-dev.lan`), and aligns the public and callback URLs. Additional environment variables let you tune the behaviour:

- `COLLABORA_ENABLE` (`true`/`false`) toggles the automation.
- `COLLABORA_PUBLIC_URL` and `COLLABORA_CALLBACK_URL` override the values exposed to browser clients and the Collabora callback respectively (unset defaults to `COLLABORA_URL` and `NC_INSTANCE_URL`).
- `COLLABORA_VERIFY_TLS` controls whether Nextcloud enforces TLS validation in the WOPI client; set to `false` when using self-signed certificates.

The Collabora container itself is seeded with permissive `aliasgroup` regexes that match any private IPv4 address (plus localhost), so WOPI handshakes continue to work even when users reach Nextcloud via an IP. The Traefik frontend also exposes an additional router (`nextcloud-private`) that listens on private IPv4 hosts, forwarding them to the main Nextcloud service—make sure your TLS certificate covers the IPs you plan to advertise.

## Deployment
Ensure the Docker network `proxy` exists:

```bash
docker network create proxy
```

Then, deploy the stack using Docker Compose:

```bash
docker-compose up -d
```

## Nextcloud Certificate Helper
To make AppAPI test deploys pass, the Nextcloud TLS certificate must include the
`nextcloud-dev.lan` Subject Alternative Name. Run `./scripts/ensure-nextcloud-cert.sh`
before starting the stack to (re)generate a development certificate and extend
`certs/custom-ca-bundle.pem` with the matching root CA. Import
`certs/dev-rootCA.pem` into your workstation trust store if browsers complain
about the new certificate.

## Runtime Logs
Use `scripts/collect-logs.sh` to stream each container's stdout/stderr into individual files under `./logs/containers`. The script requires access to the Docker socket, so run it from a shell with the same privileges you use for `docker compose`. Logs are tailed until you press Ctrl+C.

```bash
./scripts/collect-logs.sh
```

Each run truncates the previous file (for example `logs/containers/nextcloud-app.log`) before appending new output, which helps keep snapshots focused on the current debugging session.
