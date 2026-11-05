# ready.d

## Overview
Contains post-startup initialization shell scripts for the MiniStack local emulation environment. Executed automatically by the container once S3 gateway services become ready, establishing buckets, permissions, and seeding mock resources.

## Interface
- [01-seed-bucket.sh:BUCKET]: Target S3 bucket name (`"assets"`).
- [01-seed-bucket.sh:AWS_ENDPOINT_URL]: Local AWS endpoint URL environment variable (default: `http://localhost:4566`).
- [01-seed-bucket.sh:/seed]: Mount path for host seed assets synchronized into the S3 bucket.

## Invariants
- Executes with strict shell error handling (`set -eu`).
- Bucket creation is idempotent, guarding `aws s3 mb` with an `aws s3api head-bucket` probe.
- Applies an anonymous read policy allowing `s3:GetObject` on `arn:aws:s3:::assets/*`.
- Synchronization checks for existing files in `/seed` and applies `--delete` to mirror the directory structure exactly.

## Side Effects
- Invokes AWS CLI commands against local MiniStack S3 service to create buckets, set public policies, and write seed objects.

## Verification
- Run: `docker compose up ministack`
