# Snowflake File Processing Pipeline

**Snowflake-native data pipeline with Bronze/Silver layers and TPA-first isolation.**

This repository includes:
- Bronze ingestion (stages, queue, tasks, parsers)
- Silver transformation (schemas, mappings, rules)
- React + FastAPI UI for operational workflows

## Quick Start

1. Configure Snowflake access (Snow CLI or legacy config)
2. Run deployment
3. Start backend and frontend for the UI

Detailed steps:
- `QUICK_START.md` for the 10-minute walkthrough
- `DEPLOYMENT_SNOW_CLI.md` for Snowflake CLI setup and deployment

## Documentation

The consolidated docs hub lives at `docs/README.md`.

## Core Links

- `docs/USER_GUIDE.md` - end-user workflow
- `docs/DEPLOYMENT_AND_OPERATIONS.md` - deployment, ops, troubleshooting
- `README_REACT.md` - React + FastAPI architecture and local dev
- `bronze/README.md` and `silver/README.md` - layer details
