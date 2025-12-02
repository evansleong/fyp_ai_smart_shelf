import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  int _reconnectDelayMs = 1000; // start 1s

  final Map<String, List<Function>> _handlers = {
    'message': <Function>[],
    'connect': <Function>[],
    'disconnect': <Function>[],
    'error': <Function>[],
  };

  String? _customerId;
  String? _shopId;

  bool get isConnected => _isConnected;

  // Public connect
  void connect({required String customerId, required String shopId}) {
    if (_isConnected && _customerId == customerId && _shopId == shopId) {
      return;
    }
    _customerId = customerId;
    _shopId = shopId;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _reconnectDelayMs = 1000;
    _connectInternal();
  }

  void _connectInternal() {
    _disposeChannel();
    final uri = Uri.parse('wss://zmaa49rgac.execute-api.ap-southeast-1.amazonaws.com/production');
    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      _notify('error', {'message': 'Failed to create WebSocket: $e'});
      _attemptReconnect();
      return;
    }

    _channel!.stream.listen(
      (data) {
        print("🔥 WEBSOCKET RECEIVED: $data");
        try {
          final dynamic message = (data is String) ? jsonDecode(data) : data;
          _notify('message', message);
        } catch (e) {
          print("Error decoding message: $e");
          _notify('error', {'message': 'Invalid WS message: $e'});
        }
      },
      onDone: () {
        _isConnected = false;
        _notify('disconnect', null);
        if (_shouldReconnect) {
          _attemptReconnect();
        }
      },
      onError: (error, [stack]) {
        _notify('error', {'message': error.toString()});
        _disposeChannel();
        _isConnected = false;
        _notify('disconnect', null);
        if (_shouldReconnect) {
          _attemptReconnect();
        }
      },
      cancelOnError: true,
    );

    // Mark connected once sink is available; send subscribe after slight delay
    _isConnected = true;
    _reconnectAttempts = 0;
    _reconnectDelayMs = 1000;
    _notify('connect', null);

    // Send subscribe
    _send({
      'action': 'subscribe',
      'customer_id': _customerId,
      'shop_id': _shopId,
    });
  }

  void _attemptReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = _reconnectDelayMs;
      Future.delayed(Duration(milliseconds: delay), () {
        _connectInternal();
        _reconnectDelayMs = (_reconnectDelayMs * 2).clamp(1000, 30000);
      });
    } else {
      _notify('error', {'message': 'Max reconnection attempts reached'});
    }
  }

  void send(Map<String, dynamic> message) => _send(message);

  void _send(Map<String, dynamic> message) {
    final ch = _channel;
    if (ch == null) {
      _notify('error', {'message': 'WebSocket not connected'});
      return;
    }
    try {
      ch.sink.add(jsonEncode(message));
    } catch (e) {
      _notify('error', {'message': 'Failed to send WS message: $e'});
    }
  }

  // Event subscription
  Function() on(String event, Function handler) {
    _handlers.putIfAbsent(event, () => <Function>[]);
    _handlers[event]!.add(handler);
    return () => off(event, handler);
  }

  void off(String event, Function handler) {
    final list = _handlers[event];
    if (list == null) return;
    list.remove(handler);
  }

  void _notify(String event, dynamic data) {
    final list = _handlers[event] ?? const <Function>[];
    for (final fn in List<Function>.from(list)) {
      try {
        fn(data);
      } catch (_) {}
    }
  }

  void disconnect() {
    // prevent further reconnect attempts
    _shouldReconnect = false;
    // best-effort unsubscribe before closing
    try {
      if (_isConnected && _customerId != null && _shopId != null) {
        _send({
          'action': 'unsubscribe',
          'customer_id': _customerId,
          'shop_id': _shopId,
          // optional: include shelf/session if you add tracking
        });
      }
    } catch (_) {}
    _disposeChannel();
    _isConnected = false;
    _notify('disconnect', null);
  }

  void _disposeChannel() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}

// Singleton export
final webSocketService = WebSocketService();
