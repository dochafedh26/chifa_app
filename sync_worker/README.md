# Chifa Sync Agent

This is a background sync worker for the Chifa Clinic Management application. It synchronizes data between the local XAMPP database and the remote Octenium (Cloud) database.

## Architecture
- **Strategy**: "Last Modified Wins" using `updated_at` timestamps.
- **Conflict Prevention**: Uses `source_id` column to identify the origin of changes and prevent infinite sync loops.
- **Background Operation**: Runs independently of the Flutter application, ensuring a fast and responsive UI for the users.

## Setup

1. **Install Dependencies**:
   ```bash
   cd sync_worker
   npm install
   ```

2. **Configuration**:
   Edit the `.env` file with your database credentials.

## Run the Worker
You can run it manually:
```bash
node index.js
```

**Note**: The Flutter application is configured to automatically start this worker on startup when running on Windows. It will also run `npm install` automatically if `node_modules` is missing.

## Database Schema Requirements
The worker expects the following columns on all synced tables:
- `updated_at`: TIMESTAMP (Default: CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)
- `source_id`: VARCHAR (Values: 'local_server', 'cloud_server')
- `uuid`: VARCHAR(36) (Used for primary identification across nodes)

These columns are automatically added by the Flutter application's migration system.

## Synchronization Flow
1. **Push**: Query local DB for rows where `updated_at > last_push_at` and `source_id != 'cloud_server'`.
2. **Pull**: Query remote DB for rows where `updated_at > last_pull_at` and `source_id != 'local_server'`.
3. **Status**: Tracks sync progress in the `sync_status` table.
