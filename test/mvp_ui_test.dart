import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/demo_screen.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';

import 'test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<GuideType, GuideCatalog> catalogs;
  setUpAll(() async {
    catalogs = await const LocalContentRepository().load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final name in ['NotoSans', 'NotoNaskhArabic']) {
      await (FontLoader(
        name,
      )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
    }
  });
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'navigation, settings and offline states ${size.width} scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = MemoryGuideStore();
          final narration = FakeNarration();
          final settings = ReaderSettings(store, narration);
          await settings.setTextMultiplier(scale);
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: SesliRehberApp(
                store: store,
                catalogs: catalogs,
                narration: narration,
                settings: settings,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final action in ['Umreye hazırlanıyorum', 'Umredeyim']) {
            await tester.scrollUntilVisible(find.text(action), 160);
            await tester.tap(find.text(action));
            await tester.pumpAndSettle();
            expect(find.text('Adımlar · 0/18 işaretli'), findsOneWidget);
            expect(tester.takeException(), isNull);
            Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
            await tester.pumpAndSettle();
          }
          expect(store.sessions.values.map((session) => session.mode).toSet(), {
            GuideMode.learning,
            GuideMode.journey,
          });
          await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
          await tester.pumpAndSettle();
          if (size.width == 390 && scale == 1) {
            await capture(tester, key, 'home');
          }
          if (size.width == 390 && scale == 1) {
            await tester.scrollUntilVisible(
              find.text('Ses ve Arapça örnek kartını aç'),
              200,
            );
            await tester.tap(find.text('Ses ve Arapça örnek kartını aç'));
            await tester.pumpAndSettle();
            expect(find.byType(DemoScreen), findsOneWidget);
            final arabic = tester.widget<Text>(find.text('هذا نص تجريبي'));
            expect(arabic.style?.fontFamily, 'NotoNaskhArabic');
            await tester.tap(find.text('Anlatımı dinle'));
            await tester.pumpAndSettle();
            await capture(tester, key, 'audio-demo');
            Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Kafile'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Kafile hizmeti'), findsWidgets);
          expect(tester.takeException(), isNull);
          if (size.width == 390 && scale == 1) {
            await capture(tester, key, 'groups');
          }
          Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Yolculuk'));
          await tester.pumpAndSettle();
          expect(find.text('Gezi ve önemli yerler'), findsOneWidget);
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ayarlar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Koyu'));
          await tester.pumpAndSettle();
          expect(settings.themeMode, ThemeMode.dark);
          expect(tester.takeException(), isNull);
          if (size.width == 390 && scale == 1) {
            await capture(tester, key, 'settings-dark');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          narration.dispose();
          settings.dispose();
        },
      );
    }
  }
  testWidgets('home touch targets and text contrast', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['MVP_CAPTURE_UI'] != 'true') return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('docs/mvp-ui');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
