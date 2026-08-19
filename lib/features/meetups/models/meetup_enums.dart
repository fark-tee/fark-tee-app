enum MeetupStatus { upcoming, live, arrived, completed, cancelled }

enum MemberInviteStatus { accepted, pending, declined }

enum MemberArrivalStatus { notLeftYet, onTheWay, arrived, headingHome, returned }

/// The "are you okay?" safety check a member can ask of another member who
/// is [MemberArrivalStatus.headingHome]. Mirrors the backend's
/// `CheckInStatus`: a fresh request always resets [pending], which then
/// moves to exactly one of [ok]/[notOk] once the target responds.
enum CheckInStatus { none, pending, ok, notOk }
