class SubscriptionQuote {
  const SubscriptionQuote({
    required this.studentCount,
    required this.teacherCount,
    required this.studentRate,
    required this.teacherRate,
    required this.studentTotal,
    required this.teacherTotal,
    required this.monthlyTotal,
    required this.isBulkStudentRate,
  });

  final int studentCount;
  final int teacherCount;
  final int studentRate;
  final int teacherRate;
  final int studentTotal;
  final int teacherTotal;
  final int monthlyTotal;
  final bool isBulkStudentRate;
}

class SubscriptionPricing {
  static const int standardStudentRate = 285;
  static const int bulkStudentRate = 250;
  static const int teacherRate = 310;
  static const int bulkStudentThreshold = 1200;

  static int studentRateFor(int studentCount) {
    return studentCount > bulkStudentThreshold
        ? bulkStudentRate
        : standardStudentRate;
  }

  static SubscriptionQuote calculate({
    required int studentCount,
    required int teacherCount,
  }) {
    final rate = studentRateFor(studentCount);
    final studentTotal = studentCount * rate;
    final teacherTotal = teacherCount * teacherRate;

    return SubscriptionQuote(
      studentCount: studentCount,
      teacherCount: teacherCount,
      studentRate: rate,
      teacherRate: teacherRate,
      studentTotal: studentTotal,
      teacherTotal: teacherTotal,
      monthlyTotal: studentTotal + teacherTotal,
      isBulkStudentRate: studentCount > bulkStudentThreshold,
    );
  }

  static String formatInr(int amount) {
    final negative = amount < 0;
    final value = amount.abs().toString();
    if (value.length <= 3) {
      return negative ? '-₹$value' : '₹$value';
    }
    final buf = StringBuffer();
    final rem = value.length % 3;
    if (rem > 0) {
      buf.write(value.substring(0, rem));
      if (value.length > rem) buf.write(',');
    }
    for (var i = rem; i < value.length; i += 3) {
      buf.write(value.substring(i, i + 3));
      if (i + 3 < value.length) buf.write(',');
    }
    final formatted = buf.toString();
    return negative ? '-₹$formatted' : '₹$formatted';
  }
}
