class ExecutionJobStatusLog {
  final String status;
  final DateTime createdAt;

  ExecutionJobStatusLog({required this.status, required this.createdAt});

  factory ExecutionJobStatusLog.fromJson(Map<String, dynamic> json) {
    return ExecutionJobStatusLog(
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ExecutionJob {
  final String id;
  final String status;
  final String filePath;
  final DateTime createdAt;
  final String? output;
  final String? error;
  final int? exitCode;
  final DateTime? completedAt;
  final List<ExecutionJobStatusLog> statusHistory;

  ExecutionJob({
    required this.id,
    required this.status,
    required this.filePath,
    required this.createdAt,
    this.output,
    this.error,
    this.exitCode,
    this.completedAt,
    required this.statusHistory,
  });

  factory ExecutionJob.fromJson(Map<String, dynamic> json) {
    return ExecutionJob(
      id: json['id'] as String,
      status: json['status'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      output: json['output'] as String?,
      error: json['error'] as String?,
      exitCode: json['exitCode'] as int?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((e) => ExecutionJobStatusLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isTerminal =>
      status == 'FINISHED_WITH_SUCCESS' ||
      status == 'FINISHED_WITH_ERROR' ||
      status == 'FAILED';
}
