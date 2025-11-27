class ExecutionJobCreated {
  final String id;
  final String status;
  final DateTime createdAt;

  ExecutionJobCreated({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory ExecutionJobCreated.fromJson(Map<String, dynamic> json) {
    return ExecutionJobCreated(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
