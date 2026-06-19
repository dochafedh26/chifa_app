import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class SyncWorkerManager {
  static final SyncWorkerManager _instance = SyncWorkerManager._internal();
  Process? _process;

  SyncWorkerManager._internal();

  factory SyncWorkerManager() => _instance;

  Future<void> startWorker() async {
    // Only run on Desktop (Windows or Linux), not on Web/Mobile
    if (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
      return;

    try {
      final projectRoot = Directory.current.path;
      final workerDir = p.join(projectRoot, 'sync_worker');
      final nodeModulesDir = Directory(p.join(workerDir, 'node_modules'));

      // 1. Run npm install if node_modules doesn't exist
      if (!nodeModulesDir.existsSync()) {
        // node_modules not found. Running npm install...
        final installResult = await Process.run(
          'npm',
          ['install'],
          workingDirectory: workerDir,
          runInShell: true,
        );

        if (installResult.exitCode != 0) {
          // npm install failed: ${installResult.stderr}
          return;
        }
        // npm install completed successfully.
      }

      // 2. Start node index.js
      _process = await Process.start(
        'node',
        ['index.js'],
        workingDirectory: workerDir,
        runInShell: true,
      );

      // Pipe output to debug console
      _process!.stdout.listen((data) {
        final message = String.fromCharCodes(data).trim();
        if (message.isNotEmpty) {
          // Process output from stdout
        }
      });

      _process!.stderr.listen((data) {
        final message = String.fromCharCodes(data).trim();
        if (message.isNotEmpty) {
          // Process error output
        }
      });

      _process!.exitCode.then((code) {
        // Process exited with code $code
        _process = null;
      });
    } catch (e) {
      // Sync Worker: Failed to start worker: $e
    }
  }

  void stopWorker() {
    if (_process != null) {
      // Stopping Node.js sync agent...
      _process!.kill();
      _process = null;
    }
  }
}
