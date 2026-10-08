import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Paints an accessible frame before local platform/file initialization.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.load});
  final Future<Widget> Function() load;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Widget? _app;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _failed = false);
    try {
      final app = await widget.load();
      if (mounted) setState(() => _app = app);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _app ??
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RehberTheme.build(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _failed ? 'Rehber açılamadı.' : 'Rehber hazırlanıyor…',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_failed)
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Tekrar dene'),
                      )
                    else
                      const CircularProgressIndicator(
                        semanticsLabel: 'Yerel rehber yükleniyor',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Optional online services never block the usable offline application.
class DeferredValue<T> extends StatefulWidget {
  const DeferredValue({
    super.key,
    required this.initialValue,
    required this.load,
    required this.builder,
  });
  final T initialValue;
  final Future<T> Function() load;
  final Widget Function(T value) builder;

  @override
  State<DeferredValue<T>> createState() => _DeferredValueState<T>();
}

class _DeferredValueState<T> extends State<DeferredValue<T>> {
  late T _value = widget.initialValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final value = await widget.load();
        if (mounted) setState(() => _value = value);
      } catch (_) {
        // Local reading and progress remain available when the backend fails.
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_value);
}
