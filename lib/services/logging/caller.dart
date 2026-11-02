import 'package:path/path.dart' as p;

class Caller {
  const Caller(this.filename, this.scope);

  final String filename;
  final String scope;

  static Caller current() {
    final frames = StackTrace.current.toString().split('\n');
    final framePattern = RegExp(r'^#\d+\s+(.+?)\s+\((.*?):(\d+):(\d+)\)$');

    for (final frame in frames) {
      final trimmed = frame.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final match = framePattern.firstMatch(trimmed);
      if (match == null) {
        continue;
      }

      final uri = match.group(2)!;
      if (uri.contains('services/logging/')) {
        continue;
      }

      final scope = match.group(1)!.trim();
      return Caller(_fileNameFromUri(uri), scope);
    }

    return const Caller('unknown', 'unknown');
  }

  static String _fileNameFromUri(String uri) {
    final parsed = Uri.tryParse(uri);
    final path = parsed?.path.isNotEmpty == true ? parsed!.path : uri;
    return p.basename(path);
  }
}
