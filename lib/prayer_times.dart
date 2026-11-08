import 'dart:math' as math;

enum PrayerVakit {
  imsak('İmsak / Sabah'),
  gunes('Güneş'),
  ogle('Öğle'),
  ikindi('İkindi'),
  aksam('Akşam'),
  yatsi('Yatsı');

  const PrayerVakit(this.label);
  final String label;
}

class PrayerSchedule {
  const PrayerSchedule({
    required this.cityName,
    required this.date,
    required this.imsak,
    required this.gunes,
    required this.ogle,
    required this.ikindi,
    required this.aksam,
    required this.yatsi,
  });

  final String cityName;
  final DateTime date;
  final DateTime imsak;
  final DateTime gunes;
  final DateTime ogle;
  final DateTime ikindi;
  final DateTime aksam;
  final DateTime yatsi;

  Map<PrayerVakit, DateTime> get all => {
    PrayerVakit.imsak: imsak,
    PrayerVakit.gunes: gunes,
    PrayerVakit.ogle: ogle,
    PrayerVakit.ikindi: ikindi,
    PrayerVakit.aksam: aksam,
    PrayerVakit.yatsi: yatsi,
  };

  PrayerVakit currentVakit(DateTime now) {
    if (now.isBefore(imsak)) return PrayerVakit.yatsi;
    if (now.isBefore(gunes)) return PrayerVakit.imsak;
    if (now.isBefore(ogle)) return PrayerVakit.gunes;
    if (now.isBefore(ikindi)) return PrayerVakit.ogle;
    if (now.isBefore(aksam)) return PrayerVakit.ikindi;
    if (now.isBefore(yatsi)) return PrayerVakit.aksam;
    return PrayerVakit.yatsi;
  }

  PrayerVakit nextVakit(DateTime now) {
    if (now.isBefore(imsak)) return PrayerVakit.imsak;
    if (now.isBefore(gunes)) return PrayerVakit.gunes;
    if (now.isBefore(ogle)) return PrayerVakit.ogle;
    if (now.isBefore(ikindi)) return PrayerVakit.ikindi;
    if (now.isBefore(aksam)) return PrayerVakit.aksam;
    if (now.isBefore(yatsi)) return PrayerVakit.yatsi;
    return PrayerVakit.imsak;
  }

  Duration timeUntilNext(DateTime now) {
    final next = nextVakit(now);
    var target = all[next]!;
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }

  static String formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static PrayerSchedule forLocation({
    required String cityName,
    required double latitude,
    required double longitude,
    required double timeZoneOffsetHours,
    DateTime? forDate,
  }) {
    final date = forDate ?? DateTime.now();
    final year = date.year;
    final month = date.month;
    final day = date.day;

    // Day of year calculation
    final N = date.difference(DateTime(year, 1, 1)).inDays + 1;

    // Fractional year in radians
    final gamma = 2 * math.pi / 365 * (N - 1);

    // Equation of time in minutes
    final eqtime =
        229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    // Solar declination in radians
    final decl =
        0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final latRad = latitude * (math.pi / 180);

    // Solar noon in minutes from midnight local time
    final solarNoon = 720 - 4 * longitude - eqtime + (timeZoneOffsetHours * 60);

    // Hour angle helper for a given solar altitude angle alpha (in degrees)
    double? hourAngle(double alphaDeg) {
      final alphaRad = alphaDeg * (math.pi / 180);
      final cosHA =
          (math.sin(alphaRad) - math.sin(latRad) * math.sin(decl)) /
          (math.cos(latRad) * math.cos(decl));
      if (cosHA < -1.0 || cosHA > 1.0) return null;
      return math.acos(cosHA) * (180 / math.pi);
    }

    // Umm al-Qura standard: Fajr (İmsak) = -18.5 deg, Sunrise/Sunset = -0.833 deg
    final haFajr = hourAngle(-18.5) ?? 108.0;
    final haSunrise = hourAngle(-0.833) ?? 90.0;

    // Asr (Shafi'i/Hanbali standard: shadow = 1)
    final asrAltRad = math.atan(
      1.0 /
          (1.0 +
              math.tan(
                (latitude - (decl * 180 / math.pi)).abs() * (math.pi / 180),
              )),
    );
    final asrAltDeg = asrAltRad * (180 / math.pi);
    final haAsr = hourAngle(asrAltDeg) ?? 45.0;

    final imsakMinutes = solarNoon - (haFajr * 4);
    final sunriseMinutes = solarNoon - (haSunrise * 4);
    final dhuhrMinutes = solarNoon;
    final asrMinutes = solarNoon + (haAsr * 4);
    final sunsetMinutes = solarNoon + (haSunrise * 4);
    // Umm al-Qura standard: Isha is 90 minutes after Maghrib
    final ishaMinutes = sunsetMinutes + 90.0;

    DateTime makeDateTime(double totalMinutes) {
      final hours = (totalMinutes / 60).floor() % 24;
      final minutes = (totalMinutes % 60).round() % 60;
      return DateTime(year, month, day, hours, minutes);
    }

    return PrayerSchedule(
      cityName: cityName,
      date: DateTime(year, month, day),
      imsak: makeDateTime(imsakMinutes),
      gunes: makeDateTime(sunriseMinutes),
      ogle: makeDateTime(dhuhrMinutes),
      ikindi: makeDateTime(asrMinutes),
      aksam: makeDateTime(sunsetMinutes),
      yatsi: makeDateTime(ishaMinutes),
    );
  }

  /// Mekke-i Mükerreme Ezan Vakitleri (UTC+3)
  static PrayerSchedule mecca({DateTime? forDate}) => forLocation(
    cityName: 'Mekke-i Mükerreme',
    latitude: 21.422487,
    longitude: 39.826206,
    timeZoneOffsetHours: 3.0,
    forDate: forDate,
  );

  /// Medine-i Münevvere Ezan Vakitleri (UTC+3)
  static PrayerSchedule medina({DateTime? forDate}) => forLocation(
    cityName: 'Medine-i Münevvere',
    latitude: 24.4672,
    longitude: 39.6111,
    timeZoneOffsetHours: 3.0,
    forDate: forDate,
  );
}
