import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/track.dart';
import 'api_service.dart';
import 'auth_service.dart';

class FriendInfo {
  final String username;
  final String displayName;
  final bool online;

  FriendInfo({
    required this.username,
    required this.displayName,
    this.online = false,
  });

  factory FriendInfo.fromJson(Map<String, dynamic> j) => FriendInfo(
        username: j['username'] as String,
        displayName: j['displayName'] as String? ?? j['username'] as String,
        online: j['online'] == true,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'online': online,
      };
}

class FriendInvite {
  final String fromUsername;
  final String fromDisplayName;

  FriendInvite({required this.fromUsername, required this.fromDisplayName});

  factory FriendInvite.fromJson(Map<String, dynamic> j) => FriendInvite(
        fromUsername: j['fromUsername'] as String,
        fromDisplayName:
            j['fromDisplayName'] as String? ?? j['fromUsername'] as String,
      );

  Map<String, dynamic> toJson() => {
        'fromUsername': fromUsername,
        'fromDisplayName': fromDisplayName,
      };
}

class ListenRequest {
  final String fromUsername;
  final String fromDisplayName;
  final String roomId;

  ListenRequest({
    required this.fromUsername,
    required this.fromDisplayName,
    required this.roomId,
  });
}

/// Friends and synced playback over a free public MQTT relay.
/// No MEZOX server, account server, or port forwarding is needed.
class FriendsService extends ChangeNotifier {
  static const String _prefix = 'mezox/v1';
  static const String _friendsKey = 'mezox_friends';
  static const String _invitesKey = 'mezox_invites';
  static const String _userKey = 'mezox_user';

  ApiService? _api;
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  final Set<String> _subscribed = <String>{};

  String _me = '';
  String _displayName = '';
  bool _connected = false;
  String? _partner;

  List<FriendInfo> friends = [];
  List<FriendInvite> invites = [];
  String? activeRoomId;
  ListenRequest? incomingListenRequest;
  String? lastListenMessage;

  /// Auto-plays a track pushed by the listen-together partner.
  void Function(Track track)? onRemotePlay;

  void attachApi(ApiService api) {
    _api = api;
    _loadLocal();
  }

  void connectSocket(String clientId, void Function(Track track) onPlaySynced) {
    onRemotePlay = onPlaySynced;
    _connect(clientId);
  }

  Future<void> _connect(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _me = (j['username'] ?? '').toString();
      _displayName = (j['displayName'] ?? _me).toString();
    }
    if (_me.isEmpty) {
      lastListenMessage = 'Sign up first to use Listen Together';
      notifyListeners();
      return;
    }

    final host = _api?.host ?? 'broker.hivemq.com';
    final id = 'mezox_${clientId.isEmpty ? const Uuid().v4() : clientId}';
    final client = MqttServerClient.withPort(host, id, 8884);
    client.secure = true;
    client.setProtocolV311();
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(id)
        .startClean()
        .keepAliveFor(30);

    client.onConnected = () {
      _connected = true;
      _subscribed.clear();
      _subscribe(_inboxTopic(_me));
      for (final f in friends) {
        _subscribe(_presenceTopic(f.username));
      }
      _publishPresence(true);
      lastListenMessage = 'Connected to public relay';
      notifyListeners();
    };
    client.onDisconnected = () {
      _connected = false;
      notifyListeners();
    };

    _client = client;
    try {
      final status = await client.connect();
      if (status == null ||
          status.returnCode != MqttConnectReturnCode.connectionAccepted) {
        _client = null;
        lastListenMessage = 'Relay connection failed';
        notifyListeners();
        return;
      }
    } catch (_) {
      _client = null;
      lastListenMessage = 'Relay unavailable, check your internet';
      notifyListeners();
      return;
    }
    _updates = client.updates?.listen(_onMessages);
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final storedFriends = prefs.getStringList(_friendsKey) ?? const <String>[];
    friends = storedFriends
        .map((s) => FriendInfo.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    final storedInvites = prefs.getStringList(_invitesKey) ?? const <String>[];
    invites = storedInvites
        .map((s) => FriendInvite.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _friendsKey,
      friends.map((f) => jsonEncode(f.toJson())).toList(),
    );
    await prefs.setStringList(
      _invitesKey,
      invites.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  String _inboxTopic(String name) => '$_prefix/inbox/$name';
  String _presenceTopic(String name) => '$_prefix/presence/$name';
  String _sessionTopic(String room) => '$_prefix/session/$room';

  void _subscribe(String topic) {
    final client = _client;
    if (client == null || _subscribed.contains(topic)) return;
    client.subscribe(topic, MqttQos.atLeastOnce);
    _subscribed.add(topic);
  }

  void _publish(
    String topic,
    Map<String, dynamic> data, {
    bool retain = false,
  }) {
    final client = _client;
    if (client == null) return;
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(data));
    final payload = builder.payload;
    if (payload != null) {
      client.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        payload,
        retain: retain,
      );
    }
  }

  void _publishPresence(bool online) {
    _publish(
      _presenceTopic(_me),
      {'type': 'presence', 'from': _me, 'displayName': _displayName, 'online': online},
      retain: true,
    );
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final publish = event.payload as MqttPublishMessage;
      final text = MqttPublishPayload.bytesToStringAsString(
        publish.payload.message,
      );
      Map<String, dynamic> data;
      try {
        data = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final topic = event.topic;
      if (topic.startsWith('$_prefix/inbox/')) {
        _handleInbox(data);
      } else if (topic.startsWith('$_prefix/presence/')) {
        _handlePresence(topic.split('/').last, data);
      } else if (topic.startsWith('$_prefix/session/')) {
        _handleSession(topic, data);
      }
    }
  }

  void _handlePresence(String name, Map<String, dynamic> data) {
    final online = data['online'] == true;
    var changed = false;
    friends = friends.map((f) {
      if (f.username == name && f.online != online) {
        changed = true;
        return FriendInfo(
          username: f.username,
          displayName: (data['displayName'] ?? f.displayName).toString(),
          online: online,
        );
      }
      return f;
    }).toList();
    if (changed) notifyListeners();
  }

  void _handleSession(String topic, Map<String, dynamic> data) {
    final room = activeRoomId;
    if (room == null || topic != _sessionTopic(room)) return;
    if ((data['from'] ?? '').toString() == _me) return;
    if (data['type'] == 'track' && data['track'] is Map) {
      onRemotePlay?.call(
        Track.fromJson(Map<String, dynamic>.from(data['track'] as Map)),
      );
    } else if (data['type'] == 'end') {
      _endListenSession(notifyPartner: false);
      lastListenMessage = 'Listen together ended';
      notifyListeners();
    }
  }

  void _handleInbox(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final from = normalizeName((data['from'] ?? '').toString());
    if (from.isEmpty || from == _me) return;
    final fromName = (data['fromDisplayName'] ?? from).toString();

    switch (type) {
      case 'friend_request':
        if (friends.any((f) => f.username == from)) return;
        if (!invites.any((i) => i.fromUsername == from)) {
          invites = [
            FriendInvite(fromUsername: from, fromDisplayName: fromName),
            ...invites,
          ];
          _saveLocal();
          notifyListeners();
        }
        break;

      case 'friend_accept':
        if (!friends.any((f) => f.username == from)) {
          friends = [
            FriendInfo(username: from, displayName: fromName, online: true),
            ...friends,
          ];
          _subscribe(_presenceTopic(from));
          _publishPresence(true);
          _saveLocal();
          notifyListeners();
        }
        break;

      case 'listen_request':
        final roomId = (data['roomId'] ?? '').toString();
        if (roomId.isEmpty || activeRoomId != null) return;
        if (!friends.any((f) => f.username == from)) return;
        incomingListenRequest = ListenRequest(
          fromUsername: from,
          fromDisplayName: fromName,
          roomId: roomId,
        );
        lastListenMessage = 'Listen request from @$from';
        notifyListeners();
        break;

      case 'listen_accept':
        final roomId = (data['roomId'] ?? '').toString();
        if (roomId.isEmpty) return;
        activeRoomId = roomId;
        _partner = from;
        _subscribe(_sessionTopic(roomId));
        incomingListenRequest = null;
        lastListenMessage = 'Listen together started';
        notifyListeners();
        break;

      case 'listen_decline':
        lastListenMessage = 'Listen request declined';
        notifyListeners();
        break;

      case 'listen_end':
        _endListenSession(notifyPartner: false);
        lastListenMessage = 'Listen together ended';
        notifyListeners();
        break;
    }
  }

  Future<void> fetchFriends() async {
    await _loadLocal();
  }

  Future<void> fetchInvites() async {
    await _loadLocal();
  }

  Future<String?> sendInvite(String username) async {
    final target = normalizeName(username);
    if (target.isEmpty) return 'Write a name first';
    if (target == _me) return 'That is you';
    if (friends.any((f) => f.username == target)) return 'Already friends';
    if (!_connected) return 'Connecting to relay, try again in one second';
    _publish(_inboxTopic(target), {
      'type': 'friend_request',
      'from': _me,
      'fromDisplayName': _displayName,
    });
    return null;
  }

  Future<void> acceptInvite(String fromUsername) async {
    final from = normalizeName(fromUsername);
    if (from.isEmpty) return;
    _publish(_inboxTopic(from), {
      'type': 'friend_accept',
      'from': _me,
      'fromDisplayName': _displayName,
    });
    if (!friends.any((f) => f.username == from)) {
      friends = [
        FriendInfo(username: from, displayName: from, online: true),
        ...friends,
      ];
      _subscribe(_presenceTopic(from));
    }
    invites = invites.where((i) => i.fromUsername != from).toList();
    _publishPresence(true);
    await _saveLocal();
    notifyListeners();
  }

  Future<String?> requestListenTogether(String friendUsername) async {
    final target = normalizeName(friendUsername);
    if (target.isEmpty) return 'Pick a friend first';
    if (!_connected) return 'Connecting to relay, try again in one second';
    final roomId = const Uuid().v4();
    _publish(_inboxTopic(target), {
      'type': 'listen_request',
      'from': _me,
      'fromDisplayName': _displayName,
      'roomId': roomId,
    });
    lastListenMessage = 'Request sent to @$target';
    notifyListeners();
    return null;
  }

  void acceptListenRequest() {
    final req = incomingListenRequest;
    if (req == null) return;
    activeRoomId = req.roomId;
    _partner = req.fromUsername;
    _subscribe(_sessionTopic(req.roomId));
    _publish(_inboxTopic(req.fromUsername), {
      'type': 'listen_accept',
      'from': _me,
      'fromDisplayName': _displayName,
      'roomId': req.roomId,
    });
    incomingListenRequest = null;
    lastListenMessage = 'Listen together started';
    notifyListeners();
  }

  void declineListenRequest() {
    final req = incomingListenRequest;
    if (req != null) {
      _publish(_inboxTopic(req.fromUsername), {
        'type': 'listen_decline',
        'from': _me,
        'roomId': req.roomId,
      });
    }
    incomingListenRequest = null;
    lastListenMessage = 'Request declined';
    notifyListeners();
  }

  void broadcastPlay(Track track) {
    final roomId = activeRoomId;
    if (roomId == null) return;
    _publish(_sessionTopic(roomId), {
      'type': 'track',
      'from': _me,
      'track': track.toJson(),
    });
  }

  void _endListenSession({required bool notifyPartner}) {
    final roomId = activeRoomId;
    if (roomId != null && _subscribed.remove(_sessionTopic(roomId))) {
      _client?.unsubscribe(_sessionTopic(roomId));
    }
    if (notifyPartner && _partner != null) {
      _publish(_inboxTopic(_partner!), {
        'type': 'listen_end',
        'from': _me,
        'roomId': roomId ?? '',
      });
      if (roomId != null) {
        _publish(_sessionTopic(roomId), {'type': 'end', 'from': _me});
      }
    }
    activeRoomId = null;
    _partner = null;
    incomingListenRequest = null;
    notifyListeners();
  }

  /// Leaves listen-together and returns to solo listening.
  void leaveListenTogether() {
    if (activeRoomId == null && incomingListenRequest == null) return;
    _endListenSession(notifyPartner: true);
    lastListenMessage = 'You are listening alone now';
    notifyListeners();
  }

  void disconnectSocket() {
    _publishPresence(false);
    _endListenSession(notifyPartner: true);
    _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    _connected = false;
    _subscribed.clear();
    try {
      client?.disconnect();
    } catch (_) {}
    onRemotePlay = null;
    notifyListeners();
  }
}
