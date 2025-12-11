class ApprovalSequence {
  final String name;
  final int order;
  final String approverGuid;
  final String approverId;

  ApprovalSequence({
    required this.name,
    required this.order,
    required this.approverGuid,
    required this.approverId,
  });

  factory ApprovalSequence.fromJson(Map<String, dynamic> json) {
    return ApprovalSequence(
      name: json['name'] as String,
      order: json['order'] as int,
      approverGuid: json['approverGuid'] as String,
      approverId: json['approverId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'order': order,
      'approverGuid': approverGuid,
      'approverId': approverId,
    };
  }
}

class WorkflowData {
  final String name;
  final String? description;
  final List<ApprovalSequence> approvalSequences;
  final String id;

  WorkflowData({
    required this.name,
    this.description,
    required this.approvalSequences,
    required this.id,
  });

  factory WorkflowData.fromJson(Map<String, dynamic> json) {
    return WorkflowData(
      name: json['name'] as String,
      description: json['description'] as String?,
      approvalSequences: (json['approvalSequences'] as List)
          .map((item) => ApprovalSequence.fromJson(item as Map<String, dynamic>))
          .toList(),
      id: json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'approvalSequences': approvalSequences.map((seq) => seq.toJson()).toList(),
      'id': id,
    };
  }
}

