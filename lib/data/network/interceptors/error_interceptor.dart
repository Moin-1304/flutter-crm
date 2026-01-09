import 'package:dio/dio.dart';
import 'package:event_bus/event_bus.dart';

class ErrorInterceptor extends Interceptor {
  final EventBus _eventBus;

  ErrorInterceptor(this._eventBus);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _eventBus.fire(UnauthorizedEvent());
    } else {
      _eventBus.fire(
        ErrorEvent(path: err.requestOptions.path, response: err.response),
      );
    }
    super.onError(err, handler);
  }
}

class UnauthorizedEvent {}

class ErrorEvent {
  final String path;
  final Response? response;

  ErrorEvent({required this.path, this.response});
}
