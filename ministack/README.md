# MiniStack

## Overview
Houses configuration and asset seeds for local development using MiniStack (LocalStack-compatible AWS emulator). It provisions a local S3 service mimicking remote asset storage for offline testing of Bible databases, glosses, and audio downloads.

## Subdirectories & Boundaries
- init: [init](./init/README.md) - Container initialization hooks and readiness scripts for bucket creation and permissions.
- assets: Local mock seed asset repository mounted at `/seed`, containing downloadable Bibles, glosses, and audio files.
