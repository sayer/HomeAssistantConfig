#!/bin/bash
echo "Boring into docker container rvc2mqtt"
sudo docker exec -it $(sudo docker ps --filter "name=rvc2" --format "{{.Names}}" | head -n 1) bash
echo "Exiting docker container rvc2mqtt"