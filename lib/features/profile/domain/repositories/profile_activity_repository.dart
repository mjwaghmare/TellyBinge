abstract class ProfileActivityRepository {
  Future<({Map<DateTime, int> tvCounts, Map<DateTime, int> movieCounts})>
  getMonthActivity({required String uid, required DateTime month});
}
