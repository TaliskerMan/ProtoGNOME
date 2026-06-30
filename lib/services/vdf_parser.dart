// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

/// Lightweight VDF (Valve Data Format) text parser.
/// Parses Steam's config.vdf / libraryfolders.vdf format.
/// This is a simplified implementation focused on the keys ProtoGNOME needs.
library;

/// Deserializer and serializer utility class for Valve Data Format (VDF) text streams.
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
        sb.writeln(
            '$tab"${_escape(entry.key)}"\t\t"${_escape(entry.value.toString())}"');
      }
    }
    return sb.toString();
  }

  static String _escape(String s) =>
      s.replaceAll('"', '\\"').replaceAll('\\', '\\\\');

  static List<String> _tokenize(String content) {
    final tokens = <String>[];
    int index = 0;
    while (index < content.length) {
      final char = content[index];
      if (char == '"') {
        // Quoted string
        index++;
        final buf = StringBuffer();
        while (index < content.length && content[index] != '"') {
          if (content[index] == '\\' && index + 1 < content.length) {
            index++;
            buf.write(content[index]);
          } else {
            buf.write(content[index]);
          }
          index++;
        }
        index++; // closing quote
        tokens.add(buf.toString());
      } else if (char == '{') {
        tokens.add('{');
        index++;
      } else if (char == '}') {
        tokens.add('}');
        index++;
      } else if (char == '/' && index + 1 < content.length && content[index + 1] == '/') {
        // Line comment
        while (index < content.length && content[index] != '\n') {
          index++;
        }
      } else if (char == '\n' || char == '\r' || char == '\t' || char == ' ') {
        index++;
      } else {
        // Unquoted token
        final buf = StringBuffer();
        while (index < content.length &&
            content[index] != ' ' &&
            content[index] != '\n' &&
            content[index] != '\r' &&
            content[index] != '\t' &&
            content[index] != '"' &&
            content[index] != '{' &&
            content[index] != '}') {
          buf.write(content[index]);
          index++;
        }
        if (buf.isNotEmpty) tokens.add(buf.toString());
      }
    }
    return tokens;
  }
}

/// Parser state tracker traversing a token stream.
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
