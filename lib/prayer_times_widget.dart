import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'prayer_times.dart';

class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({super.key});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  bool _isMecca = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final schedule = _isMecca
        ? PrayerSchedule.mecca(forDate: now)
        : PrayerSchedule.medina(forDate: now);

    final current = schedule.currentVakit(now);
    final next = schedule.nextVakit(now);
    final remaining = schedule.timeUntilNext(now);
    final remHours = remaining.inHours;
    final remMins = remaining.inMinutes % 60;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2B26), Color(0xFF1B4D44)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RehberTheme.gold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Location Switcher & Next Prayer Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: RehberTheme.goldLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          schedule.cityName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // City toggle pill
              InkWell(
                onTap: () => setState(() => _isMecca = !_isMecca),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMecca
                              ? Icons.location_city_rounded
                              : Icons.mosque_rounded,
                          size: 13,
                          color: RehberTheme.goldLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isMecca ? 'Medine’ye Geç' : 'Mekke’ye Geç',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Countdown banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Sıradaki: ${next.label}',
                    style: const TextStyle(
                      color: RehberTheme.goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  remHours > 0
                      ? '$remHours sa $remMins dk kaldı'
                      : '$remMins dk kaldı',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 6 Prayer Times Row
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final vakit in PrayerVakit.values) ...[
                  _buildVakitItem(
                    vakit: vakit,
                    time: schedule.all[vakit]!,
                    isCurrent: current == vakit,
                    isNext: next == vakit,
                  ),
                  if (vakit != PrayerVakit.values.last)
                    const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVakitItem({
    required PrayerVakit vakit,
    required DateTime time,
    required bool isCurrent,
    required bool isNext,
  }) {
    final name = switch (vakit) {
      PrayerVakit.imsak => 'İmsak',
      PrayerVakit.gunes => 'Güneş',
      PrayerVakit.ogle => 'Öğle',
      PrayerVakit.ikindi => 'İkindi',
      PrayerVakit.aksam => 'Akşam',
      PrayerVakit.yatsi => 'Yatsı',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isNext
            ? RehberTheme.gold.withValues(alpha: 0.25)
            : (isCurrent ? Colors.white12 : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: isNext
            ? Border.all(color: RehberTheme.goldLight, width: 1)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
              color: isNext ? RehberTheme.goldLight : Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            PrayerSchedule.formatTime(time),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isNext ? Colors.white : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}
