#!/bin/bash
docker exec -it $(docker ps --filter "name=rvc2" --format "{{.Names}}" | head -n 1) bash