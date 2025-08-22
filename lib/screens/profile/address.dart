import 'package:flutter/material.dart';

class Address {
  final String id;
  final String type;
  final String street;
  final String apartment;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final String? landmark;
  final bool isDefault;

  Address({
    required this.id,
    required this.type,
    required this.street,
    this.apartment = '',
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
    this.landmark,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'street': street,
      'apartment': apartment,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'landmark': landmark,
      'isDefault': isDefault,
    };
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] ?? '',
      type: map['type'] ?? 'home',
      street: map['street'] ?? '',
      apartment: map['apartment'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipCode: map['zipCode'] ?? '',
      country: map['country'] ?? '',
      landmark: map['landmark'],
      isDefault: map['isDefault'] ?? false,
    );
  }
}