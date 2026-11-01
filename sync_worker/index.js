const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
require('dotenv').config();
const mysql = require('mysql2/promise');

const BATCH_SIZE = 50;
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

const tables = [
    'patients',
    'appointments',
    'medicalrecords',
    'medicalrecord_services',
    'prescriptions',
    'modern_prescriptions',
    'bilans',
    'bilan_type',
    'invoices',
    'payments',
    'expenses',
    'employees',
    'hospitalizations',
    'duty_reports',
    'duty_patient_entries',
    'treatments_duty_patient_entry',
    'inventory',
    'soins_medicaux',
    'soins_services',
    'lettres',
    'arret_de_travail',
    'certificat_bonne_sante',
    'certificat_dispension_sport',
    'certificat_aptitude_sport',
    'interpretation_ecg',
    'certificat_maladie_chronique',
    'ordonnance_type',
    'patients_fideles',
    'patients_suivi',
    'patient_suivi_categories',
];

function log(level, message, data = null) {
    const timestamp = new Date().toISOString();
    const logMessage = data ? `${message} ${JSON.stringify(data)}` : message;
    console[level](`[${timestamp}] [${level.toUpperCase()}] ${logMessage}`);
}

function logInfo(msg, data) { log('info', msg, data); }
function logError(msg, data) { log('error', msg, data); }
function logWarn(msg, data) { log('warn', msg, data); }

async function getPool(dbConfig) {
    return mysql.createPool({
        host: dbConfig.host,
        port: dbConfig.port,
        user: dbConfig.user,
        password: dbConfig.password,
        database: dbConfig.database,
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
        enableKeepAlive: true,
        keepAliveInitialDelay: 10000,
        connectTimeout: 30000,
    });
}

const localConfig = {
    host: process.env.LOCAL_DB_HOST || '127.0.0.1',
    port: parseInt(process.env.LOCAL_DB_PORT) || 3306,
    user: process.env.LOCAL_DB_USER || 'chiffa',
    password: process.env.LOCAL_DB_PASS || 'MyNewPass@2025',
    database: process.env.LOCAL_DB_NAME || 'clinic',
};

const remoteConfig = {
    host: process.env.REMOTE_DB_HOST || 'srv50.octenium.net',
    port: parseInt(process.env.REMOTE_DB_PORT) || 3306,
    user: process.env.REMOTE_DB_USER || 'rnhgnubg_chifa',
    password: process.env.REMOTE_DB_PASS || 'MyNetPass@2026',
    database: process.env.REMOTE_DB_NAME || 'rnhgnubg_chifa',
};

let localPool, remotePool;

async function withRetry(fn, context = '', maxRetries = MAX_RETRIES) {
    let lastError;
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await fn();
        } catch (error) {
            lastError = error;
            logWarn(`Attempt ${attempt}/${maxRetries} failed for ${context}: ${error.message}`);
            if (attempt < maxRetries) {
                await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS * attempt));
            }
        }
    }
    throw lastError;
}

async function buildPushUpsertSql(tableName, data) {
    const keys = Object.keys(data).map(k => `\`${k}\``).join(', ');
    const placeholders = Object.keys(data).map(() => '?').join(', ');
    const updates = Object.keys(data).map(k => {
        if (k === 'updated_at') {
            return `\`updated_at\` = IF(VALUES(\`updated_at\`) > \`updated_at\`, VALUES(\`updated_at\`), \`updated_at\`)`;
        }
        return `\`${k}\` = IF(VALUES(\`updated_at\`) > \`updated_at\`, VALUES(\`${k}\`), \`${k}\`)`;
    }).join(', ');
    return {
        sql: `INSERT INTO \`${tableName}\` (${keys}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE ${updates}`,
        values: Object.values(data)
    };
}

async function buildPullUpsertSql(tableName, data) {
    const keys = Object.keys(data).map(k => `\`${k}\``).join(', ');
    const placeholders = Object.keys(data).map(() => '?').join(', ');
    const updates = Object.keys(data).map(k => {
        if (k === 'updated_at') {
            return `\`updated_at\` = IF(VALUES(\`updated_at\`) > \`updated_at\`, VALUES(\`updated_at\`), \`updated_at\`)`;
        }
        return `\`${k}\` = IF(VALUES(\`updated_at\`) > \`updated_at\`, VALUES(\`${k}\`), \`${k}\`)`;
    }).join(', ');
    return {
        sql: `INSERT INTO \`${tableName}\` (${keys}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE ${updates}`,
        values: Object.values(data)
    };
}

function buildUpsertSql(tableName, data) {
    const keys = Object.keys(data).map(k => `\`${k}\``).join(', ');
    const placeholders = Object.keys(data).map(() => '?').join(', ');
    const updates = Object.keys(data).map(k => `\`${k}\` = VALUES(\`${k}\`)`).join(', ');
    return {
        sql: `INSERT INTO \`${tableName}\` (${keys}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE ${updates}`,
        values: Object.values(data)
    };
}

async function insertBatch(pool, tableName, rows) {
    if (rows.length === 0) return { affectedRows: 0 };

    const connection = await pool.getConnection();
    await connection.beginTransaction();

    try {
        let totalAffected = 0;
        for (const row of rows) {
            const { sql, values } = buildUpsertSql(tableName, row);
            const result = await connection.execute(sql, values);
            totalAffected += result.affectedRows;
            // Small delay to reduce lock contention
            await new Promise(resolve => setTimeout(resolve, 10));
        }
        await connection.commit();
        return { affectedRows: totalAffected };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        connection.release();
    }
}

function resolveConflict(localRow, remoteRow, tableName) {
    const localUpdated = localRow?.updated_at ? new Date(localRow.updated_at).getTime() : 0;
    const remoteUpdated = remoteRow?.updated_at ? new Date(remoteRow.updated_at).getTime() : 0;

    if (localUpdated > remoteUpdated) {
        return localRow;
    } else if (remoteUpdated > localUpdated) {
        return remoteRow;
    }

    return remoteUpdated > localUpdated ? remoteRow : localRow;
}

async function syncTable(tableName) {
    const syncStartTime = Date.now();
    let pushedCount = 0;
    let pulledCount = 0;
    let conflictCount = 0;

    try {
        logInfo(`--- Syncing table: ${tableName} ---`);

        const [statusRows] = await localPool.execute(
            'SELECT last_push_at, last_pull_at FROM sync_status WHERE table_name = ?',
            [tableName]
        );

        let lastPushAt = statusRows.length > 0 && statusRows[0].last_push_at ? statusRows[0].last_push_at : '1970-01-01 00:00:00';
        let lastPullAt = statusRows.length > 0 && statusRows[0].last_pull_at ? statusRows[0].last_pull_at : '1970-01-01 00:00:00';

        if (lastPushAt instanceof Date) lastPushAt = lastPushAt.toISOString().slice(0, 19).replace('T', ' ');
        if (lastPullAt instanceof Date) lastPullAt = lastPullAt.toISOString().slice(0, 19).replace('T', ' ');

        const [localChanges] = await localPool.execute(
            `SELECT * FROM \`${tableName}\` WHERE updated_at > ? AND needs_sync = 1 AND (source_id IS NULL OR source_id != 'cloud_server')`,
            [lastPushAt]
        );

        if (localChanges.length > 0) {
            logInfo(`Found ${localChanges.length} local candidates for ${tableName}`);

            const isFirstSync = lastPushAt === '1970-01-01 00:00:00';
            let rowsToPush = localChanges;

            if (isFirstSync) {
                const [remoteUuidRows] = await remotePool.execute(
                    `SELECT uuid FROM \`${tableName}\``
                );
                const remoteUuidSet = new Set(remoteUuidRows.map(r => r.uuid));

                const rowsAlreadySynced = localChanges.filter(row => remoteUuidSet.has(row.uuid));
                rowsToPush = localChanges.filter(row => !remoteUuidSet.has(row.uuid));

                if (rowsAlreadySynced.length > 0) {
                    logInfo(`${rowsAlreadySynced.length} rows already exist on remote, marking as synced`);
                    const syncedUuids = rowsAlreadySynced.filter(r => r.uuid).map(r => r.uuid);
                    for (let i = 0; i < syncedUuids.length; i += BATCH_SIZE) {
                        const batch = syncedUuids.slice(i, i + BATCH_SIZE);
                        const placeholders = batch.map(() => '?').join(', ');
                        await localPool.execute(
                            `UPDATE \`${tableName}\` SET needs_sync = 0, source_id = 'local_server' WHERE uuid IN (${placeholders})`,
                            batch
                        );
                    }
                }
            }

            if (rowsToPush.length > 0) {
                logInfo(`Pushing ${rowsToPush.length} new rows for ${tableName}`);

                const batchedRows = [];
                for (const row of rowsToPush) {
                    const data = { ...row, source_id: 'local_server', needs_sync: 0 };
                    batchedRows.push(data);
                }

                for (let i = 0; i < batchedRows.length; i += BATCH_SIZE) {
                    const batch = batchedRows.slice(i, i + BATCH_SIZE);
                    const pushRows = [];
                    for (const data of batch) {
                        const { sql, values } = await buildPushUpsertSql(tableName, data);
                        pushRows.push({ sql, values });
                    }

                    const connection = await remotePool.getConnection();
                    await connection.beginTransaction();
                    try {
                        for (const { sql, values } of pushRows) {
                            await connection.execute(sql, values);
                            await new Promise(resolve => setTimeout(resolve, 10));
                        }
                        await connection.commit();
                    } catch (error) {
                        await connection.rollback();
                        throw error;
                    } finally {
                        connection.release();
                    }
                }
            }

            const allUuids = localChanges.filter(r => r.uuid).map(r => r.uuid);
            if (allUuids.length > 0) {
                for (let i = 0; i < allUuids.length; i += BATCH_SIZE) {
                    const batch = allUuids.slice(i, i + BATCH_SIZE);
                    const placeholders = batch.map(() => '?').join(', ');
                    await localPool.execute(
                        `UPDATE \`${tableName}\` SET needs_sync = 0, source_id = 'local_server' WHERE uuid IN (${placeholders})`,
                        batch
                    );
                }
            }

            pushedCount = rowsToPush.length;

            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
            await localPool.execute(
                'INSERT INTO sync_status (table_name, last_push_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_push_at = VALUES(last_push_at)',
                [tableName, now]
            );
        }

        const [remoteChangesRaw] = await remotePool.execute(
            `SELECT * FROM \`${tableName}\` WHERE updated_at > ?`,
            [lastPullAt]
        );

        if (remoteChangesRaw.length > 0) {
            const [localUuidRows] = await localPool.execute(
                `SELECT uuid FROM \`${tableName}\``
            );
            const localUuidSet = new Set(localUuidRows.map(r => r.uuid));

            // Only skip if source_id is local_server AND row is already present locally
            const remoteChanges = remoteChangesRaw.filter(row => {
                if (row.source_id === 'local_server' && row.uuid && localUuidSet.has(row.uuid)) {
                    return false;
                }
                return true;
            });

            if (remoteChanges.length > 0) {
                const rowsToInsert = [];
                const rowsWithConflict = [];
                for (const remoteRow of remoteChanges) {
                    if (localUuidSet.has(remoteRow.uuid)) {
                        conflictCount++;
                        rowsWithConflict.push(remoteRow.uuid);
                    }
                    rowsToInsert.push(remoteRow);
                }

                if (rowsWithConflict.length > 0) {
                    logInfo(`Pulling ${remoteChanges.length} remote changes for ${tableName} (${conflictCount} conflicts)`);
                } else {
                    logInfo(`Pulling ${remoteChanges.length} remote changes for ${tableName}`);
                }

                const batchedRows = rowsToInsert.map(row => ({ ...row, source_id: 'cloud_server', needs_sync: 0 }));

            for (let i = 0; i < batchedRows.length; i += BATCH_SIZE) {
                const batch = batchedRows.slice(i, i + BATCH_SIZE);
                const pullRows = [];
                for (const data of batch) {
                    const { sql, values } = await buildPullUpsertSql(tableName, data);
                    pullRows.push({ sql, values });
                }

                const connection = await localPool.getConnection();
                await connection.beginTransaction();
                try {
                    for (const { sql, values } of pullRows) {
                        await connection.execute(sql, values);
                        await new Promise(resolve => setTimeout(resolve, 10));
                    }
                    await connection.commit();
                } catch (error) {
                    await connection.rollback();
                    throw error;
                } finally {
                    connection.release();
                }
            }

            pulledCount = rowsToInsert.length;

            const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
            await localPool.execute(
                'INSERT INTO sync_status (table_name, last_pull_at) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_pull_at = VALUES(last_pull_at)',
                [tableName, now]
            );
        }
        }

        const duration = Date.now() - syncStartTime;
        logInfo(`Completed ${tableName}: pushed=${pushedCount}, pulled=${pulledCount}, conflicts=${conflictCount} (${duration}ms)`);

        return { pushedCount, pulledCount, conflictCount, duration };

    } catch (error) {
        logError(`Error syncing table ${tableName}:`, { message: error.message, stack: error.stack });
        throw error;
    }
}

async function healthCheck() {
    try {
        await localPool.query('SELECT 1');
        await remotePool.query('SELECT 1');
        return true;
    } catch (error) {
        logError('Health check failed', { message: error.message });
        return false;
    }
}

async function runSync() {
    const syncStartTime = Date.now();
    logInfo('Starting Sync Cycle...');

    const isHealthy = await healthCheck();
    if (!isHealthy) {
        logWarn('Health check failed, skipping sync cycle');
        return;
    }

    let totalPushed = 0;
    let totalPulled = 0;
    let totalConflicts = 0;
    let failedTables = [];

    for (const table of tables) {
        try {
            const result = await withRetry(() => syncTable(table), `sync ${table}`);
            if (result) {
                totalPushed += result.pushedCount;
                totalPulled += result.pulledCount;
                totalConflicts += result.conflictCount;
            }
        } catch (error) {
            logError(`Failed to sync table ${table} after retries`);
            failedTables.push(table);
        }
    }

    const totalDuration = Date.now() - syncStartTime;
    logInfo(`Sync Cycle Completed`, {
        duration: `${totalDuration}ms`,
        totalPushed,
        totalPulled,
        totalConflicts,
        failedTables: failedTables.length > 0 ? failedTables : 'none'
    });
}

async function start() {
    try {
        localPool = await getPool(localConfig);
        remotePool = await getPool(remoteConfig);

        logInfo('Sync Agent connected to both databases');

        await runSync();

        const interval = parseInt(process.env.SYNC_INTERVAL_SECONDS || '30', 10);
        logInfo(`Scheduling sync every ${interval} seconds`);

        setInterval(runSync, interval * 1000);

    } catch (error) {
        logError('Failed to start Sync Agent', { message: error.message, stack: error.stack });
        process.exit(1);
    }
}

start();
