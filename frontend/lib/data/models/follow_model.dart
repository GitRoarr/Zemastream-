class FollowModel {
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  FollowModel({
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory FollowModel.fromJson(Map<String, dynamic> json) {
    return FollowModel(
      followerId: json['followerId'] as String,
      followingId: json['followingId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'followerId': followerId,
      'followingId': followingId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}