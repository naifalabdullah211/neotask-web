import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/user_model.dart';

void main() {
  AppUser makeUser({String? photoUrl}) => AppUser(
    uid: 'user-1',
    name: 'نايف',
    email: '400161@neotask.local',
    employeeNumber: '400161',
    role: UserRole.employee,
    accountStatus: AccountStatus.active,
    createdAt: DateTime(2026, 8, 1),
    profilePhotoUrl: photoUrl,
  );

  test('does not add an empty profile photo field to existing users', () {
    expect(makeUser().toMap().containsKey('profilePhotoUrl'), isFalse);
  });

  test('persists and restores the account profile photo URL', () {
    const url =
        'https://res.cloudinary.com/unofnu8o/image/upload/profile.jpg';
    final restored = AppUser.fromMap(makeUser(photoUrl: url).toMap());

    expect(restored.profilePhotoUrl, url);
  });
}
