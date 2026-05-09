import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

/// WebSocket client for real-time communication with the backend.
/// 
/// Manages socket connections, handles connection state changes,
/// and provides methods for joining/leaving match rooms.
class SocketClient extends ChangeNotifier {
  /// Socket.IO instance
  late IO.Socket socket;
  
  bool _isConnected = false;
  
  /// Whether the socket is currently connected
  bool get isConnected => _isConnected;

  /// Initializes and connects to the socket server.
  /// 
  /// [url] - WebSocket server URL (e.g., 'http://localhost:3000')
  /// [token] - Optional JWT token for authentication
  void init(String url, String? token) {
    socket = IO.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': token != null ? {'Authorization': 'Bearer $token'} : null,
    });

    socket.onConnect((_) {
      _isConnected = true;
      notifyListeners();
      debugPrint('⚡ Connected to socket server');
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
      debugPrint('❌ Disconnected from socket server');
    });

    socket.onConnectError((err) => debugPrint('⚠️ Connect Error: $err'));

    socket.connect();
  }

  /// Joins a match room to receive real-time updates.
  /// 
  /// [matchId] - Unique identifier of the match to join
  void joinMatch(String matchId) {
    socket.emit('match:join', matchId);
  }

  /// Leaves a match room to stop receiving updates.
  /// 
  /// [matchId] - Unique identifier of the match to leave
  void leaveMatch(String matchId) {
    socket.emit('match:leave', matchId);
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}
