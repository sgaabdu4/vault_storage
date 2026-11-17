import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'browser_check_failure.dart';
import 'browser_coverage_mapping.dart';
import 'dev_tools.dart';

final _devToolsPattern = RegExp(r'DevTools listening on (ws://\S+)');

Future<void> main() async {
  final base = File('coverage/lcov.base.info');
  if (base.existsSync()) base.deleteSync();
  await base.parent.create(recursive: true);
  final bundle = File('coverage/browser-case.js');
  final compiled = await Process.run('dart', [
    'compile',
    'js',
    '-O0',
    'test/browser/browser_download_case.dart',
    '-o',
    'coverage/browser-case.js',
  ]);
  if (compiled.exitCode != 0) throw BrowserCheckFailure('${compiled.stdout}\n${compiled.stderr}');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final served = server.asyncMap((request) => _serve(request, bundle)).drain<void>();
  final profile = await Directory.systemTemp.createTemp('vault-browser-coverage-');
  try {
    await collect(bundle, base, profile, server.port);
    stdout.writeln(
      'Browser downloads: bytes, MIME types, filename, anchor cleanup and URL revocation passed.',
    );
  } finally {
    await server.close(force: true);
    await served;
    await profile.delete(recursive: true);
  }
}

Future<void> _serve(HttpRequest request, File bundle) async {
  if (request.uri.path == '/case.js') {
    request.response.headers.contentType = ContentType('application', 'javascript');
    request.response.write(await bundle.readAsString());
  } else {
    request.response.headers.contentType = .html;
    request.response.write('<!doctype html><body><script src="/case.js"></script></body>');
  }
  await request.response.close();
}

Future<void> collect(File bundle, File output, Directory profile, int port) async {
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
    if (_devToolsPattern.firstMatch(line)?[1] case final String url when !endpoint.isCompleted) {
      endpoint.complete(.parse(url));
    }
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
    await writeDartCoverage(
      bundle,
      scriptFunctions(report, 'http://127.0.0.1:$port/case.js'),
      output,
    );
  } finally {
    await tools?.close();
    chrome.kill();
    await chrome.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        chrome.kill(.sigkill);
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
    final request = await client.getUrl(.parse('http://127.0.0.1:$port/json/list'));
    final response = await request.close();
    final pages = jsonDecode(await utf8.decoder.bind(response).join());
    final socketUrl = switch (pages) {
      final List<Object?> list => list.firstWhere(
        (candidate) => candidate is Map<String, Object?> && candidate['type'] == 'page',
        orElse: () => null,
      ),
      _ => null,
    };
    if (socketUrl case {'webSocketDebuggerUrl': final String url}) {
      return DevTools(await WebSocket.connect(url));
    }
    throw const BrowserCheckFailure('Chrome has no page to attach to');
  } finally {
    client.close(force: true);
  }
}

Future<void> waitForResult(DevTools tools) async {
  for (int attempt = 0; attempt < 100; attempt++) {
    final evaluation = await tools.call('Runtime.evaluate', {
      'expression': 'document.body && document.body.getAttribute("data-result")',
      'returnByValue': true,
    });
    final value = switch (evaluation) {
      {'result': {'value': final Object? value}} => value,
      _ => null,
    };
    if (value == 'passed') return;
    if (value is String && value.startsWith('failed:')) throw BrowserCheckFailure(value);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw const BrowserCheckFailure('Browser download checks did not complete');
}

List<Object?> scriptFunctions(DevToolsResult report, String address) {
  if (report case {'result': final List<Object?> scripts}) {
    for (final script in scripts) {
      if (script case {
        'url': final String scriptUrl,
        'functions': final List<Object?> functions,
      } when scriptUrl == address) {
        return functions;
      }
    }
  }
  throw BrowserCheckFailure('Chrome reported no coverage for $address');
}
