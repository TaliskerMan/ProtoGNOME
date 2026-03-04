// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

/// Lightweight VDF (Valve Data Format) text parser.
/// Parses Steam's config.vdf / libraryfolders.vdf format.
/// This is a simplified implementation focused on the keys ProtoGNOME needs.
library;

class VdfParser {
  /// Parse text VDF content into a nested Map structure.
  static Map<String, dynamic> parse(String content) {
    final tokens = _tokenize(content);
    final parser = _VdfTokenParser(tokens);
    return parser.parseBlock();
  }

  /// Dump a nested Map back to VDF text format.
  static String dump(Map<String, dynamic> data, {int indent = 0}) {
    final sb = StringBuffer();
    final tab = '\t' * indent;

    for (final entry in data.entries) {
      if (entry.value is Map) {
        sb.writeln('$tab"${_escape(entry.key)}"');
        sb.writeln('$tab{');
        sb.write(dump(entry.value as Map<String, dynamic>, indent: indent + 1));
        sb.writeln('$tab}');
      } else {
        sb.writeln('$tab"${_escape(entry.key)}"\t\t"${_escape(entry.value.toString())}"');
      }
    }
    return sb.toString();
  }

  static String _escape(String s) => s.replaceAll('"', '\\"').replaceAll('\\', '\\\\');

  static List<String> _tokenize(String content) {
    final tokens = <String>[];
    int i = 0;
    while (i < content.length) {
      final c = content[i];
      if (c == '"') {
        // Quoted string
        i++;
        final buf = StringBuffer();
        while (i < content.length && content[i] != '"') {
          if (content[i] == '\\' && i + 1 < content.length) {
            i++;
            buf.write(content[i]);
          } else {
            buf.write(content[i]);
          }
          i++;
        }
        i++; // closing quote
        tokens.add(buf.toString());
      } else if (c == '{') {
        tokens.add('{');
        i++;
      } else if (c == '}') {
        tokens.add('}');
        i++;
      } else if (c == '/' && i + 1 < content.length && content[i + 1] == '/') {
        // Line comment
        while (i < content.length && content[i] != '\n') i++;
      } else if (c == '\n' || c == '\r' || c == '\t' || c == ' ') {
        i++;
      } else {
        // Unquoted token
        final buf = StringBuffer();
        while (i < content.length &&
            content[i] != ' ' &&
            content[i] != '\n' &&
            content[i] != '\r' &&
            content[i] != '\t' &&
            content[i] != '"' &&
            content[i] != '{' &&
            content[i] != '}') {
          buf.write(content[i]);
          i++;
        }
        if (buf.isNotEmpty) tokens.add(buf.toString());
      }
    }
    return tokens;
  }
}

class _VdfTokenParser {
  final List<String> tokens;
  int pos = 0;

  _VdfTokenParser(this.tokens);

  Map<String, dynamic> parseBlock() {
    final result = <String, dynamic>{};
    while (pos < tokens.length) {
      final token = tokens[pos];
      if (token == '}') {
        pos++;
        break;
      }
      if (pos + 1 >= tokens.length) break;
      final key = token;
      pos++;
      final next = tokens[pos];
      if (next == '{') {
        pos++;
        result[key] = parseBlock();
      } else {
        result[key] = next;
        pos++;
      }
    }
    return result;
  }
}
