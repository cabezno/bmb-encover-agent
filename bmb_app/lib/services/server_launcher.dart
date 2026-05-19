import 'dart:io';
import 'dart:async';

class ServerLauncher {
  Process? _serverProcess;
  bool _isRunning = false;
  Timer? _healthTimer;

  bool get isRunning => _isRunning;

  /// Inicia el servidor BMB en segundo plano (solo Windows)
  Future<bool> start() async {
    if (!Platform.isWindows) return false;
    if (_isRunning) return true;

    // Ruta del servidor relativa al ejecutable
    final scriptDir = Directory.current.path;
    final serverScript = '$scriptDir\\app_server.py';

    // Si no está en la misma carpeta, buscar en Desktop\BMB\
    String actualScript = serverScript;
    if (!File(serverScript).existsSync()) {
      final homeDir = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Pc Nasa';
      final altPath = '$homeDir\\Desktop\\BMB\\app_server.py';
      if (File(altPath).existsSync()) {
        actualScript = altPath;
      } else {
        print('[ServerLauncher] app_server.py no encontrado');
        return false;
      }
    }

    try {
      // Matar procesos python viejos (pero no a nosotros mismos)
      await Process.run('taskkill', ['/f', '/im', 'python.exe'],
          runInShell: true);
      await Future.delayed(const Duration(seconds: 1));

      // Iniciar servidor oculto
      _serverProcess = await Process.start(
        'python',
        [actualScript, '--port', '8643', '--verbose'],
        runInShell: true,
        mode: ProcessStartMode.normal,
      );

      // Loggear output del servidor
      _serverProcess!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        print('[BMB Server] $data');
      });
      _serverProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        print('[BMB Server ERR] $data');
      });

      // Esperar a que el servidor esté listo
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final client = await HttpClient().getUrl(
              Uri.parse('http://localhost:8643/health'));
          final response = await client.close();
          if (response.statusCode == 200) {
            _isRunning = true;
            print('[ServerLauncher] Servidor BMB iniciado OK');
            _startHealthCheck();
            return true;
          }
        } catch (_) {
          // Aún no responde
        }
      }

      print('[ServerLauncher] Timeout esperando servidor');
      return false;
    } catch (e) {
      print('[ServerLauncher] Error: $e');
      return false;
    }
  }

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final client = await HttpClient().getUrl(
            Uri.parse('http://localhost:8643/health'));
        final response = await client.close();
        if (response.statusCode != 200) {
          _isRunning = false;
          print('[ServerLauncher] Servidor caído!');
          // Reintentar
          start();
        }
      } catch (_) {
        _isRunning = false;
        print('[ServerLauncher] Servidor no responde');
      }
    });
  }

  Future<void> stop() async {
    _healthTimer?.cancel();
    try {
      await Process.run('taskkill', ['/f', '/im', 'python.exe'],
          runInShell: true);
    } catch (_) {}
    _serverProcess?.kill();
    _serverProcess = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
  }
}
