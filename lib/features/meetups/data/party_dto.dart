/// Wire DTOs mirroring the backend's party/trip/position schemas
/// (docs/openapi.yaml: PartyResponse, PartyMemberResponse, PositionResponse,
/// TripResponse). Kept separate from the app's own `Meetup`/`MeetupMember`
/// view models, which [HttpMeetupRepository] builds from these.
class PartyDto {
  PartyDto({
    required this.id,
    required this.name,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.targetTime,
    required this.createdById,
    required this.createdByName,
    this.note,
  });

  factory PartyDto.fromJson(Map<String, dynamic> json) {
    return PartyDto(
      id: json['id'] as String,
      name: json['name'] as String,
      destinationName: json['destinationName'] as String,
      destinationLat: (json['destinationLat'] as num).toDouble(),
      destinationLng: (json['destinationLng'] as num).toDouble(),
      targetTime: DateTime.parse(json['targetTime'] as String),
      createdById: json['createdById'] as String,
      createdByName: json['createdByName'] as String,
      note: json['note'] as String?,
    );
  }

  final String id;
  final String name;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final DateTime targetTime;
  final String createdById;
  final String createdByName;
  final String? note;
}

class PartyMemberDto {
  PartyMemberDto({
    required this.id,
    required this.partyId,
    required this.userId,
    required this.userDisplayName,
    required this.userProfileImage,
    required this.status,
    required this.tripStatus,
    required this.checkInStatus,
    this.checkInRequestedByUserId,
  });

  factory PartyMemberDto.fromJson(Map<String, dynamic> json) {
    return PartyMemberDto(
      id: json['id'] as String,
      partyId: json['partyId'] as String,
      userId: json['userId'] as String,
      userDisplayName: json['userDisplayName'] as String,
      userProfileImage: json['userProfileImage'] as String? ?? '',
      status: json['status'] as String,
      tripStatus: json['tripStatus'] as String? ?? 'PENDING_DEPARTURE',
      checkInStatus: json['checkInStatus'] as String? ?? 'NONE',
      checkInRequestedByUserId: json['checkInRequestedByUserId'] as String?,
    );
  }

  final String id;
  final String partyId;
  final String userId;
  final String userDisplayName;
  final String userProfileImage;

  /// Raw backend status string: "PENDING" or "ACCEPTED".
  final String status;

  /// Raw backend trip status string: "PENDING_DEPARTURE", "DEPARTED",
  /// "ARRIVED", "RETURNING", or "RETURNED". Only ever moves forward through
  /// that sequence.
  final String tripStatus;

  /// Raw backend check-in status string: "NONE", "PENDING", "OK", or
  /// "NOT_OK".
  final String checkInStatus;
  final String? checkInRequestedByUserId;
}

/// Mirrors the backend's `PartyInviteResponse`: a pending party membership
/// row (`member.status == "PENDING"`) plus the party it's for.
class PartyInviteDto {
  PartyInviteDto({required this.party, required this.member});

  factory PartyInviteDto.fromJson(Map<String, dynamic> json) {
    return PartyInviteDto(
      party: PartyDto.fromJson(json['party'] as Map<String, dynamic>),
      member: PartyMemberDto.fromJson(json['member'] as Map<String, dynamic>),
    );
  }

  final PartyDto party;
  final PartyMemberDto member;
}

class PositionDto {
  PositionDto({
    required this.id,
    required this.tripId,
    required this.partyId,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.recordedAt,
    required this.estimatedDurationSeconds,
    required this.estimatedArrivalAt,
  });

  factory PositionDto.fromJson(Map<String, dynamic> json) {
    return PositionDto(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      partyId: json['partyId'] as String,
      userId: json['userId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      estimatedDurationSeconds: json['estimatedDurationSeconds'] as int? ?? 0,
      estimatedArrivalAt: json['estimatedArrivalAt'] != null
          ? DateTime.parse(json['estimatedArrivalAt'] as String)
          : null,
    );
  }

  final String id;
  final String tripId;
  final String partyId;
  final String userId;
  final double lat;
  final double lng;
  final DateTime recordedAt;

  /// OSRM-computed estimated travel time, in seconds, from this position to
  /// the member's trip destination as of when it was recorded.
  final int estimatedDurationSeconds;
  final DateTime? estimatedArrivalAt;
}
