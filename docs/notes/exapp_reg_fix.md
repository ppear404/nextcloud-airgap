# Registering an app from a manifest file

## 1. Download the manifest into /tmp inside the Nextcloud container
docker exec -u www-data nextcloud-app \
  sh -c "curl -fsSL https://raw.githubusercontent.com/nextcloud/test-deploy/main/appinfo/info.xml >/tmp/test-deploy-info.xml"

## 2. Register the app from the manifest
docker exec -u www-data nextcloud-app \
  php occ app_api:app:register \
    --info-xml /tmp/test-deploy-info.xml \
    test-deploy \
    harp_proxy_docker \
    --wait-finish

## 3. Enable it and confirm the status (This is run the deploy test from the cli. You may want the GUI instead)
docker exec -u www-data nextcloud-app php occ app_api:app:enable test-deploy
