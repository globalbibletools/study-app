import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/logging/log_writer.dart';

class RecordingLogWriter implements LogWriter {
  final List<LogStatement> statements = [];

  @override
  void write(LogStatement statement) => statements.add(statement);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}
