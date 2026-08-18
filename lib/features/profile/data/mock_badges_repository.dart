import '../models/profile_badge.dart';

/// No badge-earning backend logic exists yet - this just supplies the two
/// badges shown in the reference Profile screen.
class MockBadgesRepository {
  Future<List<ProfileBadge>> getBadges() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      ProfileBadge(
        title: 'ตรงเวลาตลอด',
        description: 'มาถึงก่อนเวลาหรือตรงเวลา 5 ครั้งติดต่อกัน',
      ),
      ProfileBadge(
        title: 'ไว้ใจได้',
        description: 'ตรงเวลาอย่างน้อย 80% ของตี้ทั้งหมด',
      ),
    ];
  }
}
