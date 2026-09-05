import 'package:flutter/foundation.dart';

/// Supported action types for counter presses.
enum CounterActionType {
  increment('Increment'),
  decrement('Decrement'),
  reset('Reset');

  final String label;
  const CounterActionType(this.label);
}

/// Immutable record capturing a single counter press event.
@immutable
class CounterLogEntry {
  final String id;
  final String counterId;
  final String counterTitle;
  final int counterColorHex;
  final CounterActionType actionType;
  final int changeAmount;
  final int resultingCount;
  final DateTime timestamp;

  const CounterLogEntry({
    required this.id,
    required this.counterId,
    required this.counterTitle,
    required this.counterColorHex,
    required this.actionType,
    required this.changeAmount,
    required this.resultingCount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'counterId': counterId,
      'counterTitle': counterTitle,
      'counterColorHex': counterColorHex,
      'actionType': actionType.name,
      'changeAmount': changeAmount,
      'resultingCount': resultingCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CounterLogEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return CounterLogEntry(
      id: json['id'] as String? ?? UniqueKey().toString(),
      counterId: json['counterId'] as String? ?? '',
      counterTitle: json['counterTitle'] as String? ?? 'Counter',
      counterColorHex: (json['counterColorHex'] as num?)?.toInt() ?? 0xFF2563EB,
      actionType: CounterActionType.values.firstWhere(
        (e) => e.name == json['actionType'],
        orElse: () => CounterActionType.increment,
      ),
      changeAmount: (json['changeAmount'] as num?)?.toInt() ?? 1,
      resultingCount: (json['resultingCount'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? now
          : now,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterLogEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          counterId == other.counterId &&
          counterTitle == other.counterTitle &&
          counterColorHex == other.counterColorHex &&
          actionType == other.actionType &&
          changeAmount == other.changeAmount &&
          resultingCount == other.resultingCount &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      id.hashCode ^
      counterId.hashCode ^
      counterTitle.hashCode ^
      counterColorHex.hashCode ^
      actionType.hashCode ^
      changeAmount.hashCode ^
      resultingCount.hashCode ^
      timestamp.hashCode;
}
