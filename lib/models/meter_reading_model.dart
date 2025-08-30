class MeterReading {
  final double value;
  final String type; // 'start' or 'end'
  final String? id;
  final String? nozzleId;
  final String? shiftId;
  final DateTime? timestamp;

  MeterReading({
    required this.value,
    required this.type,
    this.id,
    this.nozzleId,
    this.shiftId,
    this.timestamp,
  });

  factory MeterReading.fromJson(Map<String, dynamic> json) {
    return MeterReading(
      id: json['id'],
      value: double.parse(json['value'].toString()),
      type: json['type'],
      nozzleId: json['nozzle_id'],
      shiftId: json['shift_id'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'type': type,
      'nozzle_id': nozzleId,
      'shift_id': shiftId,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
} 