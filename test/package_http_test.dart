import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/package_downloader.dart';

class FakeHeaders implements HttpHeaders {
  final values = <String, String>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value.toString();
  }

  @override
  String? value(String name) => values[name];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeResponse(
    this.chunks, {
    this.statusCode = 200,
    this.contentLength = -1,
    String? range,
  }) {
    if (range != null) headers.values[HttpHeaders.contentRangeHeader] = range;
  }
  final Stream<List<int>> chunks;
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  final headers = FakeHeaders();
  @override
  bool get isRedirect => statusCode == 302;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => chunks.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRequest implements HttpClientRequest {
  FakeRequest(this.response);
  final Future<HttpClientResponse> response;
  @override
  final headers = FakeHeaders();
  @override
  bool followRedirects = true;
  bool aborted = false;
  @override
  Future<HttpClientResponse> close() => response;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHttp implements HttpClient {
  FakeHttp(this.request);
  final Future<HttpClientRequest> request;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) => request;
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late File file;
  final uri = Uri.parse('https://packages.example.test/file');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('package-http-');
    file = File('${root.path}/file');
  });
  tearDown(() => root.delete(recursive: true));
  HttpPackageFileFetcher fetcher(
    FakeRequest request, {
    Duration timeout = const Duration(seconds: 1),
  }) => HttpPackageFileFetcher(
    client: FakeHttp(Future.value(request)),
    timeout: timeout,
  );
  test('valid range appends only the missing bytes', () async {
    await file.writeAsBytes([1]);
    final request = FakeRequest(
      Future.value(
        FakeResponse(
          Stream.value([2, 3]),
          statusCode: 206,
          range: 'bytes 1-2/3',
        ),
      ),
    );
    expect(
      (await fetcher(request).fetch(uri, file, expectedBytes: 3)).resumed,
      true,
    );
    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(request.headers.values[HttpHeaders.rangeHeader], 'bytes=1-');
    expect(request.followRedirects, false);
  });
  test('wrong range leaves partial file untouched', () async {
    await file.writeAsBytes([1]);
    final request = FakeRequest(
      Future.value(
        FakeResponse(
          Stream.value([2, 3]),
          statusCode: 206,
          range: 'bytes 0-1/3',
        ),
      ),
    );
    await expectLater(
      fetcher(request).fetch(uri, file, expectedBytes: 3),
      throwsA(isA<PackageDownloadException>()),
    );
    expect(await file.readAsBytes(), [1]);
    expect(request.aborted, true);
  });
  test('server ignoring range safely starts from zero', () async {
    await file.writeAsBytes([9]);
    final request = FakeRequest(
      Future.value(FakeResponse(Stream.value([1, 2, 3]), contentLength: 3)),
    );
    expect(
      (await fetcher(request).fetch(uri, file, expectedBytes: 3)).resumed,
      false,
    );
    expect(await file.readAsBytes(), [1, 2, 3]);
  });
  test('unbounded response cannot write beyond manifest size', () async {
    final request = FakeRequest(
      Future.value(
        FakeResponse(
          Stream.fromIterable([
            [1, 2],
            [3, 4],
          ]),
        ),
      ),
    );
    await expectLater(
      fetcher(request).fetch(uri, file, expectedBytes: 3),
      throwsA(isA<PackageDownloadException>()),
    );
    expect(await file.length(), lessThanOrEqualTo(3));
    expect(request.aborted, true);
  });
  test(
    'oversized declared response is rejected before file is opened',
    () async {
      final request = FakeRequest(
        Future.value(FakeResponse(Stream.value([1, 2, 3]), contentLength: 30)),
      );
      await expectLater(
        fetcher(request).fetch(uri, file, expectedBytes: 3),
        throwsA(isA<PackageDownloadException>()),
      );
      expect(await file.exists(), false);
    },
  );
  test('stalled body times out and aborts request', () async {
    final body = StreamController<List<int>>();
    final request = FakeRequest(Future.value(FakeResponse(body.stream)));
    await expectLater(
      fetcher(
        request,
        timeout: const Duration(milliseconds: 20),
      ).fetch(uri, file, expectedBytes: 3),
      throwsA(isA<TimeoutException>()),
    );
    expect(request.aborted, true);
    await body.close();
  });
  test('late connection is aborted after handshake timeout', () async {
    final gate = Completer<HttpClientRequest>();
    final client = HttpPackageFileFetcher(
      client: FakeHttp(gate.future),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      client.fetch(uri, file, expectedBytes: 3),
      throwsA(isA<TimeoutException>()),
    );
    final request = FakeRequest(
      Future.value(FakeResponse(const Stream.empty())),
    );
    gate.complete(request);
    await Future<void>.delayed(Duration.zero);
    expect(request.aborted, true);
  });
}
