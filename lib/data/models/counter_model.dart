import 'package:flutter/foundation.dart';

/// Immutable domain model representing an individual counter with customization,
/// targets, tags, custom ordering, and timestamps.
@immutable
class CounterModel {
  final String id;
  final String title;
  final int count;
  final int step;
  final int colorHex;
  final int? target;
  final bool allowNegative;
  final String? tag;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CounterModel({
    required this.id,
    required this.title,
    this.count = 0,
    this.step = 1,
    this.colorHex = 0xFF2563EB, // Default Royal Blue
    this.target,
    this.allowNegative = false,
    this.tag,
    this.orderIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progress ratio towards target: null if no target or target <= 0;
  /// Clamped between 0.0 and 1.0.
  double? get progress {
    if (target == null || target! <= 0) return null;
    return (count / target!).clamp(0.0, 1.0);
  }

  /// Whether the user has reached or exceeded their goal.
  bool get isTargetReached {
    if (target == null || target! <= 0) return false;
    return count >= target!;
  }

  /// Percentage value integer towards goal, or null if no target.
  int? get progressPercentage {
    if (target == null || target! <= 0) return null;
    return ((count / target!) * 100).round();
  }

  /// Creates a copy of this model with updated attributes.
  CounterModel copyWith({
    String? id,
    String? title,
    int? count,
    int? step,
    int? colorHex,
    int? target,
    bool clearTarget = false,
    bool? allowNegative,
    String? tag,
    bool clearTag = false,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CounterModel(
      id: id ?? this.id,
      title: title ?? this.title,
      count: count ?? this.count,
      step: step ?? this.step,
      colorHex: colorHex ?? this.colorHex,
      target: clearTarget ? null : (target ?? this.target),
      allowNegative: allowNegative ?? this.allowNegative,
      tag: clearTag ? null : (tag ?? this.tag),
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes model to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'count': count,
      'step': step,
      'colorHex': colorHex,
      'target': target,
      'allowNegative': allowNegative,
      'tag': tag,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes model from JSON map with safe fallbacks.
  factory CounterModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return CounterModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? 'Untitled Counter',
      count: (json['count'] as num?)?.toInt() ?? 0,
      step: ((json['step'] as num?)?.toInt() ?? 1).clamp(1, 100000),
      colorHex: (json['colorHex'] as num?)?.toInt() ?? 0xFF2563EB,
      target: (json['target'] as num?)?.toInt(),
      allowNegative: json['allowNegative'] as bool? ?? false,
      tag: json['tag'] as String?,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? now
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? now
          : now,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          count == other.count &&
          step == other.step &&
          colorHex == other.colorHex &&
          target == other.target &&
          allowNegative == other.allowNegative &&
          tag == other.tag &&
          orderIndex == other.orderIndex &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      count.hashCode ^
      step.hashCode ^
      colorHex.hashCode ^
      target.hashCode ^
      allowNegative.hashCode ^
      tag.hashCode ^
      orderIndex.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
