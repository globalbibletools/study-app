#!/bin/sh
# MiniStack ready.d init script.
#
# Runs after the gateway is up (AWS_ENDPOINT_URL, credentials, and region are
# already exported by the image). Creates the bucket, opens it for anonymous
# downloads, and syncs the seeded assets from /seed.
set -eu

BUCKET="assets"

# 1. Create the bucket (idempotent).
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3 mb "s3://$BUCKET"
fi

# 2. Allow anonymous public reads on every object in the bucket.
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::${BUCKET}/*\"
    }
  ]
}"

# 3. Seed initial assets (skip if the seed directory is empty).
if [ -d /seed ] && [ "$(ls -A /seed 2>/dev/null)" ]; then
  aws s3 sync --delete /seed "s3://$BUCKET/"
fi

echo "[ministack-init] bucket '$BUCKET' ready; public URL base: ${AWS_ENDPOINT_URL:-http://localhost:4566}/$BUCKET"
