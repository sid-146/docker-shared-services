#!/bin/sh
set -e

echo "Waiting for MinIO..."
sleep 5

echo "Configuring MinIO client..."
mc alias set minio http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

echo "Creating buckets..."

mc mb -p minio/mlflow || true
mc mb -p minio/milvus || true

echo "Verifying buckets..."
mc ls minio

echo "Buckets ready."