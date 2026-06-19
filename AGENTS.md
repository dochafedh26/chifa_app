# Project Chifa - Entry Point

## Overview
Chifa is a clinic management application built with Flutter, featuring a hybrid local-remote MySQL database architecture.

## AI Instructions
As an AI assistant, you MUST follow the rules defined in the `.agents/` directory.

### Mandatory Reading
1. [Project Rules (SoT)](file:///d:/DEV-FOLDER/FLUTTER/chifa/.agents/context/agents-rules.json)
2. [Work Index](file:///d:/DEV-FOLDER/FLUTTER/chifa/.agents/context/ai-work-index.yaml)

### Key Workflows
- **Database Sync**: Managed via `SyncManager` and `RemoteDatabaseService`.
- **Printing**: Managed via `PdfGenerationService` and `printing` package.

## Commands
- `/sync` - Instructions for checking/fixing sync logic.
- `/print` - Instructions for adding preview/print features.

---
*For human developers, see [.users/context/agents-rules.md](file:///d:/DEV-FOLDER/FLUTTER/chifa/.users/context/agents-rules.md).*
