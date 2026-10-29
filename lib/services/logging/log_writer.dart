import 'package:gbt/services/logging/log_statement.dart';

abstract class LogWriter {
  void write(LogStatement statement);

  Future<void> flush() async {}

  Future<void> close() async {}
}
