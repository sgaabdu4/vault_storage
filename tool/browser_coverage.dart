import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'browser_coverage_mapping.dart';

Future<void> main() async {
  final base = File('coverage/lcov.base.info');
  if (base.existsSync()) base.deleteSync();
  await base.parent.create(recursive: true);
  final javascript = File('coverage/browser-case.js');
  final compiled = await Process.run('dart', [
    'compile',
    'js',
    '-O0',
    'tool/browser_download_case.dart',
    '-o',
    'coverage/browser-case.js',
  ]);
  if (compiled.exitCode != 0) throw StateError('${compiled.stdout}\n${compiled.stderr}');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requests = server.listen((request) async {
    if (request.uri.path == '/case.js') {
      request.response.headers.contentType = ContentType('application', 'javascript');
      request.response.write(await javascript.readAsString());
    } else {
      request.response.headers.contentType = ContentType.html;
      request.response.write('<!doctype html><body><script src="/case.js"></script></body>');
    }
    await request.response.close();
  });
  final profile = await Directory.systemTemp.createTemp('vault-browser-coverage-');
  try {
    await collect(javascript, base, profile, server.port);
    stdout.writeln(
      'Browser downloads: bytes, MIME types, filename, anchor cleanup and URL revocation passed.',
    );
  } finally {
    await requests.cancel();
    await server.close(force: true);
    await profile.delete(recursive: true);
  }
}

Future<void> collect(File javascript, File output, Directory profile, int port) async {
  const arguments = [
    '--headless=new',
    '--remote-debugging-port=0',
    '--user-data-dir=.',
    '--no-first-run',
    '--no-default-browser-check',
    'about:blank',
  ];
  final chrome = Platform.isMacOS
      ? await Process.start(
          '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
          arguments,
          workingDirectory: profile.path,
        )
      : await Process.start('google-chrome', arguments, workingDirectory: profile.path);
  final endpoint = Completer<Uri>();
  final errors = chrome.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) {
    final match = RegExp(r'DevTools listening on (ws://\S+)').firstMatch(line);
    if (match != null && !endpoint.isCompleted) endpoint.complete(Uri.parse(match[1]!));
  });
  final logs = chrome.stdout.drain<void>();
  DevTools? tools;
  try {
    final address = await endpoint.future.timeout(const Duration(seconds: 20));
    tools = await connectPage(address.port);
    await tools.call('Profiler.enable');
    await tools.call('Profiler.startPreciseCoverage', {'callCount': true, 'detailed': true});
    await tools.call('Page.navigate', {'url': 'http://127.0.0.1:$port/'});
    await waitForResult(tools);
    final report = await tools.call('Profiler.takePreciseCoverage');
    final script = (report['result']! as List<Object?>).cast<Map<String, Object?>>().singleWhere(
      (entry) => entry['url'] == 'http://127.0.0.1:$port/case.js',
    );
    await writeDartCoverage(javascript, script['functions']! as List<Object?>, output);
  } finally {
    await tools?.close();
    chrome.kill();
    await chrome.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        chrome.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await errors.cancel();
    await logs;
  }
}

Future<DevTools> connectPage(int port) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/json/list'));
    final response = await request.close();
    final pages = jsonDecode(await utf8.decoder.bind(response).join()) as List<Object?>;
    final page = pages.cast<Map<String, Object?>>().firstWhere((value) => value['type'] == 'page');
    return DevTools(await WebSocket.connect(page['webSocketDebuggerUrl']! as String));
  } finally {
    client.close(force: true);
  }
}

Future<void> waitForResult(DevTools tools) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final result = await tools.call('Runtime.evaluate', {
      'expression': 'document.body && document.body.getAttribute("data-result")',
      'returnByValue': true,
    });
    final value = (result['result']! as Map<String, Object?>)['value'];
    if (value == 'passed') return;
    if (value is String && value.startsWith('failed:')) throw StateError(value);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Browser download checks did not complete');
}

class DevTools {
  DevTools(this.socket) {
    subscription = socket.listen((Object? message) {
      final data = jsonDecode(message! as String) as Map<String, Object?>;
      final response = pending.remove(data['id']);
      if (response == null) return;
      if (data.containsKey('error')) {
        response.completeError(StateError('${data['error']}'));
      } else {
        response.complete(data['result']! as Map<String, Object?>);
      }
    });
  }

  final WebSocket socket;
  final pending = <int, Completer<Map<String, Object?>>>{};
  late final StreamSubscription<Object?> subscription;
  var nextId = 0;

  Future<Map<String, Object?>> call(String method, [Map<String, Object?> params = const {}]) {
    final id = ++nextId;
    final response = Completer<Map<String, Object?>>();
    pending[id] = response;
    socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return response.future.timeout(const Duration(seconds: 20));
  }

  Future<void> close() async {
    await subscription.cancel();
    await socket.close();
  }
}
