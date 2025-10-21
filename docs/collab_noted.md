# Collabora Notes

## Collabora Online is a powerful LibreOffice-based online office suite with collaborative editing, which supports all major documents, spreadsheet and presentation file formats and works together with all modern browsers. 

## Nextcloud Office requires a separate server running Collabora Online to provide editing capabilities. Collabora Online requires a separate server acting as a WOPI-like Client to provide editing capabilities.

https://help.nextcloud.com/t/collabora-integration-guide/151879

## Objective 
The docker compose deploys the collabora container, but needs to be integrated at build time. Add the collabora intergration so that it is available during the initial deployment. 

Users must be able to collaborate. 
Access to the Nextcloud instance from ANY private IP address is required. 

## Troubleshooting

## Implementation Summary
- `appapi-bootstrap.sh` now installs/enables the `richdocuments` app and wires it to Collabora, including optional TLS tweaks driven by the `COLLABORA_*` environment variables.
- `docker-compose.yml` exposes the new Collabora settings to the Nextcloud container, expands the Collabora `aliasgroup` patterns to cover every private IPv4/localhost combination, and adds a Traefik router so private IP hosts reach Nextcloud out of the box.
