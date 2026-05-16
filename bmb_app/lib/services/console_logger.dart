import '../widgets/common/console_panel.dart';

/// Convenience helper to log from anywhere in the app.
class ConsoleLogger {
  static final ConsoleLogProvider _provider = ConsoleLogProvider();

  static void info(String msg, {String? details}) =>
      _provider.info(msg, details: details);
  static void warn(String msg, {String? details}) =>
      _provider.warn(msg, details: details);
  static void error(String msg, {String? details}) =>
      _provider.error(msg, details: details);
  static void tool(String msg, {String? details}) =>
      _provider.tool(msg, details: details);
  static void state(String msg, {String? details}) =>
      _provider.state(msg, details: details);
  static void clear() => _provider.clear();
}
