# Project Chifa - Entry Point

## Overview
Chifa is a clinic management application built with Flutter, featuring a hybrid local-remote Supabase/PostgreSQL and SQLite database architecture.

## AI Instructions
As an AI assistant, you MUST follow the rules defined in the `.agents/` directory.

### Mandatory Reading
1. [Project Rules (SoT)](file:///d:/DEV-FOLDER/FLUTTER/chifa_app/.agents/context/agents-rules.json)
2. [Work Index](file:///d:/DEV-FOLDER/FLUTTER/chifa_app/.agents/context/ai-work-index.yaml)

### Key Workflows
- **Database Cloud & Sync**: Managed via `SyncManager`, `DatabaseManager`, and Supabase Serverless RPC.
- **Printing**: Managed via `PdfGenerationService` and `printing` package.

## Commands
- `/sync` - Instructions for checking/fixing sync logic.
- `/print` - Instructions for adding preview/print features.
