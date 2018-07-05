#!/bin/bash -e

echo "${REGISTRY_PASSWORD}" | docker login -u "${REGISTRY_USERNAME}" --password-stdin

docker push "${IMAGE_NAME}"
