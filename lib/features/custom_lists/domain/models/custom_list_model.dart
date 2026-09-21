import 'package:equatable/equatable.dart';
import 'custom_list_item_model.dart';

class CustomListModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CustomListItemModel> items;

  const CustomListModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  int get itemCount => items.length;

  bool containsItem(int id, String mediaType) {
    return items.any((item) => item.id == id && item.mediaType == mediaType);
  }

  factory CustomListModel.fromJson(Map<String, dynamic> json, String docId) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((item) => CustomListItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    return CustomListModel(
      id: docId,
      name: json['name'] as String? ?? 'Untitled List',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  CustomListModel copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CustomListItemModel>? items,
  }) {
    return CustomListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
    items,
  ];
}
