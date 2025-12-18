// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour_plan_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TourPlanStore on _TourPlanStore, Store {
  Computed<bool>? _$loadingComputed;

  @override
  bool get loading => (_$loadingComputed ??=
          Computed<bool>(() => super.loading, name: '_TourPlanStore.loading'))
      .value;

  late final _$monthAtom = Atom(name: '_TourPlanStore.month', context: context);

  @override
  DateTime get month {
    _$monthAtom.reportRead();
    return super.month;
  }

  @override
  set month(DateTime value) {
    _$monthAtom.reportWrite(value, super.month, () {
      super.month = value;
    });
  }

  late final _$fetchMonthFutureAtom =
      Atom(name: '_TourPlanStore.fetchMonthFuture', context: context);

  @override
  ObservableFuture<List<TourPlanEntry>> get fetchMonthFuture {
    _$fetchMonthFutureAtom.reportRead();
    return super.fetchMonthFuture;
  }

  @override
  set fetchMonthFuture(ObservableFuture<List<TourPlanEntry>> value) {
    _$fetchMonthFutureAtom.reportWrite(value, super.fetchMonthFuture, () {
      super.fetchMonthFuture = value;
    });
  }

  late final _$entriesAtom =
      Atom(name: '_TourPlanStore.entries', context: context);

  @override
  List<TourPlanEntry> get entries {
    _$entriesAtom.reportRead();
    return super.entries;
  }

  @override
  set entries(List<TourPlanEntry> value) {
    _$entriesAtom.reportWrite(value, super.entries, () {
      super.entries = value;
    });
  }

  late final _$loadMonthAsyncAction =
      AsyncAction('_TourPlanStore.loadMonth', context: context);

  @override
  Future<void> loadMonth(
      {String? employeeId, String? customer, TourPlanEntryStatus? status}) {
    return _$loadMonthAsyncAction.run(() => super
        .loadMonth(employeeId: employeeId, customer: customer, status: status));
  }

  late final _$approveAsyncAction =
      AsyncAction('_TourPlanStore.approve', context: context);

  @override
  Future<void> approve(List<String> ids) {
    return _$approveAsyncAction.run(() => super.approve(ids));
  }

  late final _$sendBackAsyncAction =
      AsyncAction('_TourPlanStore.sendBack', context: context);

  @override
  Future<void> sendBack(List<String> ids, String comment) {
    return _$sendBackAsyncAction.run(() => super.sendBack(ids, comment));
  }

  late final _$rejectAsyncAction =
      AsyncAction('_TourPlanStore.reject', context: context);

  @override
  Future<void> reject(List<String> ids, String comment) {
    return _$rejectAsyncAction.run(() => super.reject(ids, comment));
  }

  @override
  String toString() {
    return '''
month: ${month},
fetchMonthFuture: ${fetchMonthFuture},
entries: ${entries},
loading: ${loading}
    ''';
  }
}
