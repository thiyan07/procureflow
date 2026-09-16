class CentreStats {
  final int totalFarmersToday;
  final int waiting;
  final int processing;
  final int completed;
  final int paymentPending;
  final double avgWaitMinutes;
  final String peakPeriod;
  final double noShowRate;

  const CentreStats({
    required this.totalFarmersToday,
    required this.waiting,
    required this.processing,
    required this.completed,
    required this.paymentPending,
    required this.avgWaitMinutes,
    required this.peakPeriod,
    required this.noShowRate,
  });
}

class LoadPrediction {
  final String slotLabel; // 08:00-09:00
  final int expectedFarmers;
  final bool isPeak;
  const LoadPrediction({required this.slotLabel, required this.expectedFarmers, this.isPeak = false});
}

class AIPrediction {
  final int estimatedWaitMinutes;
  final String reasoning;
  const AIPrediction({required this.estimatedWaitMinutes, required this.reasoning});
}
