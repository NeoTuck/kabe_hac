import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';
import 'package:hac_umre_sesli_rehber/progress_store.dart';

class MemoryGuideStore extends ProgressStore {
  int nextId = 1;
  final Map<int, GuideSession> sessions = {};
  final Map<int, Set<String>> marks = {};
  final Map<String, String> appValues = {};
  final Map<String, Set<String>> travelFavorites = {};

  @override
  Future<GuideSession> openOrCreateSession({
    required GuideType type,
    required GuideMode mode,
    required HajjProfile? profile,
    required String firstStepId,
    required String contentVersion,
  }) async {
    for (final session in sessions.values.toList().reversed) {
      if (session.type == type &&
          session.mode == mode &&
          session.profile == profile) {
        return session;
      }
    }
    final session = GuideSession(
      id: nextId++,
      mode: mode,
      currentStepId: firstStepId,
      contentVersion: contentVersion,
      type: type,
      profile: profile,
      updatedAt: nextId,
    );
    sessions[session.id] = session;
    return session;
  }

  @override
  Future<GuideSession> startNewJourney({
    required GuideType type,
    required HajjProfile? profile,
    required String firstStepId,
    required String contentVersion,
  }) async {
    final session = GuideSession(
      id: nextId++,
      mode: GuideMode.journey,
      currentStepId: firstStepId,
      contentVersion: contentVersion,
      type: type,
      profile: profile,
      updatedAt: nextId,
    );
    sessions[session.id] = session;
    return session;
  }

  @override
  Future<GuideSession?> readSession(int id) async => sessions[id];

  @override
  Future<GuideSession?> readMostRecentSession() async =>
      sessions.isEmpty ? null : sessions.values.last;

  @override
  Future<void> saveCurrentStep(int sessionId, String stepId) async {
    sessions[sessionId] = sessions[sessionId]!.copyWith(currentStepId: stepId);
  }

  @override
  Future<Set<String>> readMarkedStepIds(int sessionId) async =>
      Set.of(marks[sessionId] ?? {});

  @override
  Future<void> setStepMarked(int sessionId, String stepId, bool marked) async {
    final values = marks.putIfAbsent(sessionId, () => {});
    if (marked) {
      values.add(stepId);
    } else {
      values.remove(stepId);
    }
  }

  @override
  Future<String?> readAppValue(String key) async => appValues[key];

  @override
  Future<void> saveAppValue(String key, String value) async {
    appValues[key] = value;
  }

  @override
  Future<Set<String>> readTravelFavoriteIds(String itemType) async =>
      Set.of(travelFavorites[itemType] ?? {});

  @override
  Future<void> setTravelFavorite(
    String itemType,
    String itemId,
    bool favorite,
  ) async {
    final values = travelFavorites.putIfAbsent(itemType, () => {});
    if (favorite) {
      values.add(itemId);
    } else {
      values.remove(itemId);
    }
  }
}

class FakeNarration extends NarrationService {
  NarrationState current = const NarrationState(NarrationStatus.idle);
  int stopCount = 0;
  double speed = 1;

  @override
  NarrationState get state => current;

  void finish() {
    current = NarrationState(NarrationStatus.completed, asset: current.asset);
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playAsset(String asset, {String? title}) async {
    current = NarrationState(NarrationStatus.playing, asset: asset);
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    current = NarrationState(NarrationStatus.paused, asset: current.asset);
    notifyListeners();
  }

  @override
  Future<void> resume() async {
    current = NarrationState(NarrationStatus.playing, asset: current.asset);
    notifyListeners();
  }

  @override
  Future<void> replay() => resume();

  @override
  Future<void> stop() async {
    stopCount++;
    current = const NarrationState(NarrationStatus.idle);
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }
}
