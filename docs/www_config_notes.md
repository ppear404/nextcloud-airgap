
# Setting Trusted Domains in Nextcloud Docker Container
docker exec -it nextcloud-app bash -lc '
php occ config:system:set trusted_domains 0 --value=nextcloud-dev.lan
php occ config:system:set trusted_domains 1 --value=nextcloud-1233.ppear.net
'


# inside the app container
php occ config:system:set trusted_domains 0 --value=nextcloud-dev.lan
php occ config:system:set trusted_domains 1 --value=nextcloud-dev.ppear.net
php occ config:system:set overwriteprotocol --value=https
php occ config:system:delete overwritehost || true
php occ config:system:delete overwrite.cli.url || true

