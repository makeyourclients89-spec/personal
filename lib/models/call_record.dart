class TranscriptEntry {
  final String speaker; // 'ai' or 'caller' or 'user'
  final String text;
  final DateTime timestamp;

  TranscriptEntry({
    required this.speaker,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) => TranscriptEntry(
    speaker: json['speaker'] ?? 'ai',
    text: json['text'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
  );
}

enum CallStatus {
  aiScreened,
  takenOver,
  declined,
  missed,
  realScreened,
  directUser,
}

class CallRecord {
  final String id;
  final String callerName;
  final String callerNumber;
  final DateTime timestamp;
  final Duration duration;
  final String category;
  final CallStatus status;
  final String keyIntent;
  final String aiSummary;
  final String urgency;
  final List<TranscriptEntry> transcript;
  final bool isSimulated;
  final bool hasRecording;
  final Duration recordingDuration;

  CallRecord({
    required this.id,
    required this.callerName,
    required this.callerNumber,
    required this.timestamp,
    required this.duration,
    required this.category,
    required this.status,
    required this.keyIntent,
    required this.aiSummary,
    required this.urgency,
    required this.transcript,
    this.isSimulated = true,
    this.hasRecording = true,
    Duration? recordingDuration,
  }) : recordingDuration = recordingDuration ?? duration;

  Map<String, dynamic> toJson() => {
    'id': id,
    'callerName': callerName,
    'callerNumber': callerNumber,
    'timestamp': timestamp.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'category': category,
    'status': status.name,
    'keyIntent': keyIntent,
    'aiSummary': aiSummary,
    'urgency': urgency,
    'transcript': transcript.map((t) => t.toJson()).toList(),
    'isSimulated': isSimulated,
    'hasRecording': hasRecording,
    'recordingDurationSeconds': recordingDuration.inSeconds,
  };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: json['id'] ?? '',
    callerName: json['callerName'] ?? 'Unknown Caller',
    callerNumber: json['callerNumber'] ?? '',
    timestamp: json['timestamp'] != null ? (DateTime.tryParse(json['timestamp']) ?? DateTime.now()) : DateTime.now(),
    duration: Duration(seconds: json['durationSeconds'] ?? 0),
    category: json['category'] ?? 'General',
    status: CallStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => CallStatus.aiScreened,
    ),
    keyIntent: json['keyIntent'] ?? '',
    aiSummary: json['aiSummary'] ?? '',
    urgency: json['urgency'] ?? 'Low',
    transcript: (json['transcript'] as List<dynamic>? ?? [])
        .map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    isSimulated: json['isSimulated'] ?? true,
    hasRecording: json['hasRecording'] ?? true,
    recordingDuration: Duration(seconds: json['recordingDurationSeconds'] ?? (json['durationSeconds'] ?? 0)),
  );
}
