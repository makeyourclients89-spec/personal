import 'dart:async';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _methodChannel = MethodChannel('call_detection/telephony');
  static const EventChannel _eventChannel = EventChannel('call_detection/events');

  static final NativeBridge instance = NativeBridge._();
  NativeBridge._() {
    _initEventStream();
  }

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  void _initEventStream() {
    try {
      _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            _eventsController.add(Map<String, dynamic>.from(event));
          }
        },
        onError: (dynamic error) {
          // ignore or forward
        },
      );
    } catch (_) {
      // Missing plugin or non-Android platform
    }
  }

  Future<Map<String, dynamic>> getPermissionsStatus() async {
    try {
      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getPermissionsStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'phoneState': false,
      'callLog': false,
      'audio': false,
      'notification': false,
      'screeningRole': false,
      'roleSupported': true,
      'androidVersion': 30,
    };
  }

  Future<String> requestRuntimePermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<String>('requestRuntimePermissions');
      return res ?? 'REQUESTED';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  Future<String> requestCallScreeningRole() async {
    try {
      final res = await _methodChannel.invokeMethod<String>('requestCallScreeningRole');
      return res ?? 'OK';
    } on PlatformException catch (e) {
      return 'ERROR: ${e.message ?? e.code}';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _methodChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  Future<void> openDefaultAppsSettings() async {
    try {
      await _methodChannel.invokeMethod('openDefaultAppsSettings');
    } catch (_) {}
  }

  Future<void> speak(String text, {String lang = 'hi'}) async {
    try {
      await _methodChannel.invokeMethod('speak', {'text': text, 'lang': lang});
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _methodChannel.invokeMethod('stopSpeaking');
    } catch (_) {}
  }

  Future<void> startListening() async {
    try {
      await _methodChannel.invokeMethod('startListening');
    } catch (_) {}
  }

  Future<void> stopListening() async {
    try {
      await _methodChannel.invokeMethod('stopListening');
    } catch (_) {}
  }

  Future<void> vibrate({int duration = 400}) async {
    try {
      await _methodChannel.invokeMethod('vibrate', {'duration': duration});
    } catch (_) {}
  }
}
