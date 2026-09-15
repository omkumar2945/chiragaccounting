#!/usr/bin/env bash
set -euo pipefail

region="ap-south-1"
account_id="513954968199"
image_name="simple-docker-service-06f108204807"
repository_uri="${account_id}.dkr.ecr.${region}.amazonaws.com/${image_name}"
cluster="chiragaccounting-cluster"
service="chiragaccounting-api-service"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# This script deploys only the backend container image. It does not modify RDS data.
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "${account_id}.dkr.ecr.${region}.amazonaws.com"

docker build --tag "${image_name}:latest" --file "${script_dir}/backend/Dockerfile" "${script_dir}/backend"
docker tag "${image_name}:latest" "${repository_uri}:latest"
docker push "${repository_uri}:latest"

aws ecs update-service \
  --cluster "$cluster" \
  --service "$service" \
  --force-new-deployment \
  --region "$region" \
  --output text > /dev/null

aws ecs wait services-stable \
  --cluster "$cluster" \
  --services "$service" \
  --region "$region"

echo "Backend deployed successfully."
