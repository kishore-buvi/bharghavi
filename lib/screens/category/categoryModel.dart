// File: lib/models/categoryModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.imageUrl,
    this.metadata,
  });

  // Factory constructor to create CategoryModel from Firestore document
  factory CategoryModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? 'category',
      color: data['color'] ?? '#6200EA',
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      imageUrl: data['imageUrl'],
      metadata: data['metadata'],
    );
  }

  // Factory constructor to create CategoryModel from Firestore DocumentSnapshot
  factory CategoryModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel.fromFirestore(doc.id, data);
  }

  // Convert CategoryModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
      'metadata': metadata,
    };
  }

  // Convert CategoryModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'imageUrl': imageUrl,
      'metadata': metadata,
    };
  }

  // Factory constructor to create CategoryModel from JSON
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'category',
      color: json['color'] ?? '#6200EA',
      isActive: json['isActive'] ?? true,
      sortOrder: json['sortOrder'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      imageUrl: json['imageUrl'],
      metadata: json['metadata'],
    );
  }

  // Create a copy of CategoryModel with updated fields
  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CategoryModel{id: $id, name: $name, description: $description, icon: $icon, color: $color, isActive: $isActive, sortOrder: $sortOrder}';
  }

  // Validation methods
  bool get isValid {
    return name.isNotEmpty &&
        description.isNotEmpty &&
        icon.isNotEmpty &&
        color.isNotEmpty;
  }

  String? validate() {
    if (name.isEmpty) return 'Category name is required';
    if (name.length < 2) return 'Category name must be at least 2 characters';
    if (name.length > 50) return 'Category name must be less than 50 characters';

    if (description.isEmpty) return 'Category description is required';
    if (description.length > 200) return 'Category description must be less than 200 characters';

    if (icon.isEmpty) return 'Category icon is required';
    if (color.isEmpty) return 'Category color is required';

    // Validate color format (hex color)
    final colorRegex = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$');
    if (!colorRegex.hasMatch(color)) return 'Invalid color format';

    return null; // Valid
  }

  // Helper methods for UI
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get displayName => name.trim();

  String get displayDescription => description.trim();

  // Get formatted creation date
  String get formattedCreatedAt {
    if (createdAt == null) return 'Unknown';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  // Get formatted update date
  String get formattedUpdatedAt {
    if (updatedAt == null) return 'Unknown';
    return '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}';
  }
}