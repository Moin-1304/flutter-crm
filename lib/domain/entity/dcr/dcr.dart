import 'package:flutter/foundation.dart';

enum DcrStatus { draft, submitted, approved, rejected, sentBack }

enum GeoProximity { at, near, away }

@immutable
class DcrEntry {
  const DcrEntry({
    required this.id,
    required this.date,
    required this.cluster,
    required this.customer,
    required this.purposeOfVisit,
    required this.callDurationMinutes,
    required this.productsDiscussed,
    required this.samplesDistributed,
    required this.keyDiscussionPoints,
    required this.status,
    required this.employeeId,
    required this.employeeName,
    this.linkedTourPlanId,
    this.geoProximity = GeoProximity.at,
    this.customerLatitude,
    this.customerLongitude,
    this.createdAt,
    this.updatedAt,
    this.typeOfWorkId,
    this.cityId,
    this.customerId,
    this.detailId,
    this.clusterId,
  });

  final String id;
  final DateTime date;
  final String cluster;
  final String customer;
  final String purposeOfVisit;
  final int callDurationMinutes;
  final String productsDiscussed;
  final String samplesDistributed;
  final String keyDiscussionPoints;
  final DcrStatus status;
  final String employeeId;
  final String employeeName;
  final String? linkedTourPlanId;
  final GeoProximity geoProximity;
  final double? customerLatitude;
  final double? customerLongitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? typeOfWorkId;
  final int? cityId;
  final int? customerId;
  final int? detailId; // TourPlanDCRDetails child Id for edit
  final int? clusterId; // ClusterId from detail

  DcrEntry copyWith({
    String? id,
    DateTime? date,
    String? cluster,
    String? customer,
    String? purposeOfVisit,
    int? callDurationMinutes,
    String? productsDiscussed,
    String? samplesDistributed,
    String? keyDiscussionPoints,
    DcrStatus? status,
    String? employeeId,
    String? employeeName,
    String? linkedTourPlanId,
    GeoProximity? geoProximity,
    double? customerLatitude,
    double? customerLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? typeOfWorkId,
    int? cityId,
    int? customerId,
    int? detailId,
    int? clusterId,
  }) {
    return DcrEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      cluster: cluster ?? this.cluster,
      customer: customer ?? this.customer,
      purposeOfVisit: purposeOfVisit ?? this.purposeOfVisit,
      callDurationMinutes: callDurationMinutes ?? this.callDurationMinutes,
      productsDiscussed: productsDiscussed ?? this.productsDiscussed,
      samplesDistributed: samplesDistributed ?? this.samplesDistributed,
      keyDiscussionPoints: keyDiscussionPoints ?? this.keyDiscussionPoints,
      status: status ?? this.status,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      linkedTourPlanId: linkedTourPlanId ?? this.linkedTourPlanId,
      geoProximity: geoProximity ?? this.geoProximity,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      typeOfWorkId: typeOfWorkId ?? this.typeOfWorkId,
      cityId: cityId ?? this.cityId,
      customerId: customerId ?? this.customerId,
      detailId: detailId ?? this.detailId,
      clusterId: clusterId ?? this.clusterId,
    );
  }
}

class CreateDcrParams {
  const CreateDcrParams({
    required this.date,
    required this.cluster,
    required this.customer,
    required this.purposeOfVisit,
    required this.callDurationMinutes,
    required this.productsDiscussed,
    required this.samplesDistributed,
    required this.keyDiscussionPoints,
    this.linkedTourPlanId,
    this.geoProximity = GeoProximity.at,
    required this.employeeId,
    required this.employeeName,
    this.submit = false,
    this.typeOfWorkId,
    this.cityId,
    this.customerId,
    this.userId,
    this.bizunit,
    this.latitude,
    this.longitude,
  });

  final DateTime date;
  final String cluster;
  final String customer;
  final String purposeOfVisit;
  final int callDurationMinutes;
  final String productsDiscussed;
  final String samplesDistributed;
  final String keyDiscussionPoints;
  final String? linkedTourPlanId;
  final GeoProximity geoProximity;
  final String employeeId;
  final String employeeName;
  final bool submit;
  // ID fields for API calls
  final int? typeOfWorkId;
  final int? cityId;
  final int? customerId;
  final int? userId;
  final int? bizunit;
  final double? latitude;
  final double? longitude;
}


