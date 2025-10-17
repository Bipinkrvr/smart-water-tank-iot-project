// lib/models/daily_stat.dart

class DailyStat {
  final String date;
  final int motorRunTimeSeconds;
  final int waterUsedPercent;

  DailyStat({
    required this.date,
    required this.motorRunTimeSeconds,
    required this.waterUsedPercent,
  });
}