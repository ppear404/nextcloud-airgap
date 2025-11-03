
# Setting Trusted Domains in Nextcloud Docker Container
docker exec -it nextcloud-app bash -lc '
php occ config:system:set trusted_domains 0 --value=nextcloud-dev.lan
php occ config:system:set trusted_domains 1 --value=nextcloud-1233.ppear.net
'