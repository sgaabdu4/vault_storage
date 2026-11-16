import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'browser_check_failure.dart';

typedef DevToolsResult = Map<String, Object?>;

class DevTools {
  DevTools(this._socket) : _messages = _socket.asBroadcastStream();

  final WebSocket _socket;
  final Stream<Object?> _messages;
  int _nextId = 0;

  Future<DevToolsResult> call(String method, [Map<String, Object?> params = const {}]) {
    final callNumber = ++_nextId;
    _socket.add(jsonEncode({'id': callNumber, 'method': method, 'params': params}));
    return _answer(callNumber).timeout(const Duration(seconds: 20));
  }

  Future<DevToolsResult> _answer(int callNumber) async {
    await for (final message in _messages) {
      if (message is String) {
        switch (jsonDecode(message)) {
          case {'id': final int answered, 'error': final Object error} when answered == callNumber:
            throw BrowserCheckFailure(error.toString());
          case {'id': final int answered, 'result': final DevToolsResult result}
              when answered == callNumber:
            return result;
          case {'id': final int answered} when answered == callNumber:
            return const {};
        }
      }
    }
    throw const BrowserCheckFailure('Chrome closed the DevTools connection');
  }

  Future<void> close() => _socket.close();
}
