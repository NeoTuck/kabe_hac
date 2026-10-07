import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/app_theme.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';

import 'test_fakes.dart';

class EmptyOutbox extends MemoryGuideStore {
  @override
  Future<List<GroupOutboxMessage>> readGroupOutbox({
    MessageOutboxStatus? status,
  }) async => [];
}

class HistoryRepository extends UnconfiguredGroupRepository {
  String? uid = 'user-a';
  int base = 100;
  int historyCalls = 0;
  bool offline = false;
  bool revoked = false;
  bool duplicate = false;
  bool deleteOld = false;
  Completer<GroupMessagePage>? gate;
  @override
  bool get configured => true;
  @override
  String? get userId => uid;
  void switchAccount() {
    uid = 'user-b';
    notifyListeners();
  }

  Map<String, dynamic> row(int i) => {
    'id': '20000000-0000-0000-0000-${i.toString().padLeft(12, '0')}',
    'created_at': '2026-10-07T20:00:00.123456Z',
    'sender_id': 'user-a',
    'body': 'Mesaj $i',
    'recipient_id': null,
    'deleted_at': deleteOld && i == 99 ? '2026-10-07T20:01:00Z' : null,
  };
  @override
  Future<GroupSnapshot> snapshot(String groupId) async => GroupSnapshot(
    members: const [],
    messages: List.generate(100, (i) => row(base + i)),
    announcements: const [],
    programs: const [],
    routes: const [],
  );
  @override
  Future<GroupMessagePage> olderMessages(
    String groupId, {
    required MessageCursor before,
  }) async {
    historyCalls++;
    if (gate != null) return gate!.future;
    if (revoked) throw GroupAccessError();
    if (offline) throw StateError('offline');
    final end = int.parse(before.id.split('-').last);
    final start = max(0, end - 50);
    return GroupMessagePage(
      messages: [
        for (var i = start; i < end; i++) row(i),
        if (duplicate) row(end),
      ],
      hasMore: start > 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final frame = GlobalKey();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSans.ttf'))).load();
  });
  Future<void> open(
    WidgetTester tester,
    HistoryRepository repository, {
    bool small = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = small
        ? const Size(320, 568)
        : const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (small) {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MaterialApp(
          theme: RehberTheme.build(Brightness.light),
          home: GroupDetailScreen(
            group: const GroupRecord('group-a', 'Kafile'),
            repository: repository,
            store: EmptyOutbox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(
    WidgetTester tester,
    String text, {
    double delta = 200,
  }) => tester.scrollUntilVisible(
    find.text(text),
    delta,
    maxScrolls: 100,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  Future<void> load(WidgetTester tester) async {
    await scrollTo(tester, 'Eski mesajları yükle');
    await tester.tap(find.text('Eski mesajları yükle'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, HistoryRepository repository) async {
    await tester.pumpWidget(const SizedBox.shrink());
    repository.dispose();
  }

  testWidgets('older pages are deduplicated and preserve chronological order', (
    tester,
  ) async {
    final repo = HistoryRepository()..duplicate = true;
    await open(tester, repo);
    await load(tester);
    expect(find.text('Sohbet · 150 mesaj'), findsOneWidget);
    if (Platform.environment['MVP_CAPTURE_UI'] == 'true') {
      await tester.runAsync(() async {
        final boundary =
            frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/mvp-ui').create(recursive: true);
        await File('docs/mvp-ui/group-history.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await scrollTo(tester, 'Mesaj 50');
    expect(find.text('Mesaj 50'), findsOneWidget);
    repo.duplicate = false;
    await load(tester);
    expect(find.text('Sohbet · 200 mesaj'), findsOneWidget);
    expect(find.text('Eski mesajları yükle'), findsNothing);
    await close(tester, repo);
  });

  testWidgets('refresh revalidates history and removes deleted message text', (
    tester,
  ) async {
    final repo = HistoryRepository();
    await open(tester, repo);
    await load(tester);
    repo.deleteOld = true;
    await scrollTo(tester, 'Kafileyi yenile', delta: -250);
    await tester.tap(find.text('Kafileyi yenile'));
    await tester.pumpAndSettle();
    expect(repo.historyCalls, 2);
    expect(find.text('Sohbet · 150 mesaj'), findsOneWidget);
    await scrollTo(tester, 'Mesaj silindi.');
    expect(find.text('Mesaj silindi.'), findsOneWidget);
    expect(find.text('Mesaj 99'), findsNothing);
    await close(tester, repo);
  });

  testWidgets('offline history load offers retry and keeps current messages', (
    tester,
  ) async {
    final repo = HistoryRepository()..offline = true;
    await open(tester, repo);
    await load(tester);
    expect(find.textContaining('Eski mesajlar alınamadı'), findsOneWidget);
    expect(find.text('Sohbet · 100 mesaj'), findsOneWidget);
    repo.offline = false;
    await load(tester);
    expect(find.text('Sohbet · 150 mesaj'), findsOneWidget);
    expect(find.textContaining('Eski mesajlar alınamadı'), findsNothing);
    await close(tester, repo);
  });

  testWidgets('revoked membership clears both recent and older messages', (
    tester,
  ) async {
    final repo = HistoryRepository();
    await open(tester, repo);
    await load(tester);
    repo.revoked = true;
    await load(tester);
    expect(find.textContaining('Kafileye erişilemedi'), findsOneWidget);
    expect(find.textContaining('Sohbet ·'), findsNothing);
    expect(find.text('Mesaj 50'), findsNothing);
    await close(tester, repo);
  });

  testWidgets('account change discards an in-flight history page', (
    tester,
  ) async {
    final repo = HistoryRepository()..gate = Completer<GroupMessagePage>();
    await open(tester, repo);
    await scrollTo(tester, 'Eski mesajları yükle');
    await tester.tap(find.text('Eski mesajları yükle'));
    await tester.pump();
    repo.switchAccount();
    repo.gate!.complete(
      GroupMessagePage(messages: [repo.row(1)], hasMore: false),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Oturum değişti'), findsOneWidget);
    expect(find.text('Mesaj 1'), findsNothing);
    expect(find.textContaining('Sohbet ·'), findsNothing);
    await close(tester, repo);
  });

  testWidgets(
    'refresh supersedes pending page and does not duplicate requests',
    (tester) async {
      final repo = HistoryRepository()..gate = Completer<GroupMessagePage>();
      await open(tester, repo);
      await scrollTo(tester, 'Eski mesajları yükle');
      await tester.tap(find.text('Eski mesajları yükle'));
      await tester.pump();
      await tester.tap(find.text('Eski mesajlar yükleniyor'));
      expect(repo.historyCalls, 1);
      await scrollTo(tester, 'Kafileyi yenile', delta: -250);
      await tester.tap(find.text('Kafileyi yenile'));
      await tester.pumpAndSettle();
      repo.gate!.complete(
        GroupMessagePage(messages: [repo.row(1)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sohbet · 100 mesaj'), findsOneWidget);
      expect(find.text('Mesaj 1'), findsNothing);
      expect(find.text('Eski mesajlar yükleniyor'), findsNothing);
      await close(tester, repo);
    },
  );

  testWidgets('history supports small screens and large text', (tester) async {
    final repo = HistoryRepository();
    await open(tester, repo, small: true);
    await load(tester);
    expect(find.text('Sohbet · 150 mesaj'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester, repo);
  });

  testWidgets('history rendering is bounded to 500 messages', (tester) async {
    final repo = HistoryRepository()..base = 900;
    await open(tester, repo);
    for (var i = 0; i < 8; i++) {
      await load(tester);
    }
    expect(find.text('Sohbet · 500 mesaj'), findsOneWidget);
    expect(
      find.text('Bu ekranda en fazla 500 mesaj gösterilir.'),
      findsOneWidget,
    );
    expect(find.text('Eski mesajları yükle'), findsNothing);
    expect(repo.historyCalls, 8);
    await close(tester, repo);
  });
}
