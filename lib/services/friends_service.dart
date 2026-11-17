import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';
import '../models/track.dart';

class FriendInfo {
  final String username;
  final String displayName;
  final bool online;
  FriendInfo({required this.username, required this.displayName, this.online = false});
  factory FriendInfo.fromJson(Map<String, dynamic> j) => FriendInfo(
        username: j['username'],
        displayName: j['displayName'] ?? j['username'],
        online: j['online'] == true,
      );
}

class FriendInvite {
  final String fromUsername;
  final String fromDisplayName;
  FriendInvite({required this.fromUsername, required this.fromDisplayName});
  factory FriendInvite.fromJson(Map<String, dynamic> j) => FriendInvite(
        fromUsername: j['fromUsername'],
        fromDisplayName: j['fromDisplayName'] ?? j['fromUsername'],
      );
}

class ListenRequest {
  final String fromUsername;
  final String fromDisplayName;
  final String roomId;
  ListenRequest({required this.fromUsername, required this.fromDisplayName, required this.roomId});
}

class FriendsService extends ChangeNotifier {
  ApiService? _api;
  io.Socket? _socket;
  List<FriendInfo> friends = [];
  List<FriendInvite> invites = [];
  String? activeRoomId;
  ListenRequest? incomingListenRequest;
  String? lastListenMessage;

  /// Callback used to auto-play tracks pushed from the listen-together partner.
  void Function(Track track)? onRemotePlay;

  void attachApi(ApiService api) {
    _api = api;
  }

  void connectSocket(String token, void Function(Track track) onPlaySynced) {
    if (_api == null) return;
    onRemotePlay = onPlaySynced;
    _socket?.dispose();
    _socket = io.io(_api!.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });
    _socket!.on('invite_received', (_) => fetchInvites());
    _socket!.on('friends_updated', (_) => fetchFriends());

    // Incoming listen-together request (needs explicit accept on this device)
    _socket!.on('listen_request', (data) {
      if (data is Map) {
        incomingListenRequest = ListenRequest(
          fromUsername: (data['fromUsername'] ?? '').toString(),
          fromDisplayName: (data['fromDisplayName'] ?? data['fromUsername'] ?? '').toString(),
          roomId: (data['roomId'] ?? '').toString(),
        );
        notifyListeners();
      }
    });

    // Partner accepted our request -> we are now synced
    _socket!.on('listen_accepted', (data) {
      if (data is Map) {
        final roomId = (data['roomId'] ?? '').toString();
        if (roomId.isNotEmpty) {
          activeRoomId = roomId;
          _socket?.emit('join_room', {'roomId': roomId});
          lastListenMessage = 'Listen together started';
          notifyListeners();
        }
      }
    });

    // Partner declined or left the session -> back to solo listening
    _socket!.on('listen_ended', (_) {
      _endListenSession(notifyPartner: false);
      lastListenMessage = 'Listen together ended';
      notifyListeners();
    });

    _socket!.on('play_sync', (data) {
      // Only obey remote playback while actively in a listen session
      if (activeRoomId == null) return;
      if (data is Map) {
        final t = Track.fromJson(Map<String, dynamic>.from(data['track']));
        onRemotePlay?.call(t);
      }
    });
  }

  void disconnectSocket() {
    _endListenSession(notifyPartner: true);
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    onRemotePlay = null;
  }

  void _endListenSession({required bool notifyPartner}) {
    if (activeRoomId != null) {
      if (notifyPartner) {
        _socket?.emit('listen_end', {'roomId': activeRoomId});
      }
      _socket?.emit('leave_room', {'roomId': activeRoomId});
    }
    activeRoomId = null;
    incomingListenRequest = null;
    notifyListeners();
  }

  Future<void> fetchFriends() async {
    if (_api == null) return;
    final res = await _api!.dio.get('/friends');
    friends = (res.data as List)
        .map((e) => FriendInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> fetchInvites() async {
    if (_api == null) return;
    final res = await _api!.dio.get('/friends/invites');
    invites = (res.data as List)
        .map((e) => FriendInvite.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<String?> sendInvite(String username) async {
    try {
      await _api!.dio.post('/friends/invite', data: {'toUsername': username});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> acceptInvite(String fromUsername) async {
    await _api!.dio.post('/friends/accept', data: {'fromUsername': fromUsername});
    await fetchInvites();
    await fetchFriends();
  }

  /// Sends a listen-together request; session starts only after the friend accepts.
  Future<String?> requestListenTogether(String friendUsername) async {
    try {
      final res = await _api!.dio.post('/friends/listen/join',
          data: {'friendUsername': friendUsername});
      final roomId = res.data['roomId'] as String?;
      if (roomId == null) return 'Could not create session';
      _socket?.emit('listen_invite', {'roomId': roomId, 'friendUsername': friendUsername});
      lastListenMessage = 'Request sent to @$friendUsername';
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void acceptListenRequest() {
    final req = incomingListenRequest;
    if (req == null) return;
    activeRoomId = req.roomId;
    _socket?.emit('join_room', {'roomId': req.roomId});
    _socket?.emit('listen_accept', {'roomId': req.roomId, 'fromUsername': req.fromUsername});
    incomingListenRequest = null;
    lastListenMessage = 'Listen together started';
    notifyListeners();
  }

  void declineListenRequest() {
    final req = incomingListenRequest;
    if (req != null) {
      _socket?.emit('listen_decline', {'roomId': req.roomId, 'fromUsername': req.fromUsername});
    }
    incomingListenRequest = null;
    lastListenMessage = 'Request declined';
    notifyListeners();
  }

  void broadcastPlay(Track track) {
    if (activeRoomId == null) return;
    _socket?.emit('play_sync', {
      'roomId': activeRoomId,
      'track': track.toJson(),
    });
  }

  /// Leaves listen-together and returns to solo listening.
  void leaveListenTogether() {
    _endListenSession(notifyPartner: true);
    lastListenMessage = 'You are listening alone now';
    notifyListeners();
  }
}
