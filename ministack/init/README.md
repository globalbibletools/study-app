# Init

## Overview
Groups lifecycle initialization hooks and configuration scripts mounted into the MiniStack container for automating local AWS emulation setup.

## Subdirectories & Boundaries
- ready.d: [ready.d](./ready.d/README.md) - Startup shell scripts triggered when the MiniStack container reaches the ready state to provision S3 buckets and seed assets.
