import 'dart:convert';

class LspMessage {
  static String format(Map<String, dynamic> jsonRpc) {
    final content = jsonEncode(jsonRpc);
    return 'Content-Length: ${content.length}\r\n\r\n$content';
  }

  static Map<String, dynamic>? parse(String raw) {
    try {
      final separatorIndex = raw.indexOf('\r\n\r\n');
      if (separatorIndex == -1) {
        return null;
      }

      final contentPart = raw.substring(separatorIndex + 4);

      if (contentPart.isEmpty) {
        return null;
      }

      final json = jsonDecode(contentPart);
      if (json is Map<String, dynamic>) {
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic> createInitializeRequest(int id, String rootUri) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'method': 'initialize',
      'params': {
        'processId': null,
        'rootUri': rootUri,
        'capabilities': {
          'textDocument': {
            'definition': {
              'linkSupport': true,
            },
          },
        },
      },
    };
  }

  static Map<String, dynamic> createInitializedNotification() {
    return {
      'jsonrpc': '2.0',
      'method': 'initialized',
      'params': {},
    };
  }

  static Map<String, dynamic> createDidOpenNotification(
    String uri,
    String languageId,
    int version,
    String text,
  ) {
    return {
      'jsonrpc': '2.0',
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': languageId,
          'version': version,
          'text': text,
        },
      },
    };
  }

  static Map<String, dynamic> createDefinitionRequest(
    int id,
    String uri,
    int line,
    int character,
  ) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'method': 'textDocument/definition',
      'params': {
        'textDocument': {
          'uri': uri,
        },
        'position': {
          'line': line,
          'character': character,
        },
      },
    };
  }
}
