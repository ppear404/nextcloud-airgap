
# Unfinshed Tasks
- Moving past the Deploy Daemon issue. Seems irrelevant for offline installs.

# In Progress

# hpb integration at compose

Error: Websocket connection failed. Check browser console
Nextcloud base URLhttps://nextcloud-dev.lanTalk
Backend URLhttps://nextcloud-dev.lan/ocs/v2.php/apps/spreed/api/v3/signaling/backendWebSocket
URLwss://talk-dev.lan/spreed

WebSocket negotiation is now configured in Nextcloud, but the browser-side probe still fails because the workstation doesn’t trust the talk-dev.lan certificate. From the host:

curl https://talk-dev.lan (system trust) → SSL certificate problem (exit 60)
curl --cacert certs/custom-ca-bundle.pem https://talk-dev.lan/api/v1/welcome → succeeds and returns the HPB welcome payload
Manual WebSocket handshake with TLS (curl --http1.1 -H 'Connection: Upgrade' … https://talk-dev.lan/spreed) succeeds and the backend answers with the expected welcome frame.
That means the HPB service, Traefik routing, and the shared secrets that appapi-bootstrap.sh:100-283 writes are all working; the remaining failure comes from the browser refusing the TLS handshake (which also prevents the Admin UI from completing its client-side test). Turning off “Validate SSL certificate” in the Talk settings only disables the server-to-server check, so the browser still needs to trust the certificate.

What to do:

Add talk-dev.lan (and the other dev hostnames) to your workstation’s hosts file so they resolve to the Docker host.
Import certs/dev-rootCA.pem into your browser/OS trust store (or replace the dev certs with a trusted one). Firefox requires adding the root CA in Preferences → Privacy & Security → Certificates.
Refresh /settings/admin/talk. The probe should show a green success badge once the browser can open wss://talk-dev.lan/spreed.
You can double-check from the workstation with curl --cacert certs/custom-ca-bundle.pem https://talk-dev.lan/api/v1/welcome and, for the WebSocket, a tool like wscat or curl with the Upgrade headers.
No further code changes are needed—the environment wiring in docker-compose.yml:63-74, the bootstrap automation in appapi-bootstrap.sh, and the README guidance are already in place.