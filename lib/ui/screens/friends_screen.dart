import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _addCtrl = TextEditingController();
  String? _msg;

  @override
  void initState() {
    super.initState();
    final f = context.read<FriendsService>();
    f.fetchFriends();
    f.fetchInvites();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final friends = context.watch<FriendsService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signed in as @${auth.user?.username ?? ''}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _addCtrl,
              decoration: const InputDecoration(labelText: 'Add friend by username', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final err = await friends.sendInvite(_addCtrl.text.trim());
              setState(() => _msg = err ?? 'Friend invite sent');
              _addCtrl.clear();
            },
            child: const Text('Invite'),
          ),
        ]),
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: Colors.redAccent))),
        if (friends.lastListenMessage != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(friends.lastListenMessage!, style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 16),

        if (friends.incomingListenRequest != null)
          Card(
            color: Colors.red.withOpacity(0.18),
            child: ListTile(
              leading: const Icon(Icons.headphones, color: Colors.redAccent),
              title: Text('Listen request from @${friends.incomingListenRequest!.fromUsername}'),
              subtitle: Text(friends.incomingListenRequest!.fromDisplayName),
              trailing: Wrap(spacing: 8, children: [
                TextButton(onPressed: friends.declineListenRequest, child: const Text('Decline')),
                ElevatedButton(onPressed: friends.acceptListenRequest, child: const Text('Accept')),
              ]),
            ),
          ),

        if (friends.activeRoomId != null)
          Card(
            color: Colors.red.withOpacity(0.12),
            child: ListTile(
              leading: const Icon(Icons.headphones, color: Colors.redAccent),
              title: const Text('Listen together active'),
              subtitle: const Text('You and your friend hear the same songs in sync'),
              trailing: TextButton(onPressed: friends.leaveListenTogether, child: const Text('Disconnect')),
            ),
          ),

        const SizedBox(height: 12),
        const Text('Friend requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (friends.invites.isEmpty)
          const Text('No pending friend requests.', style: TextStyle(color: Colors.white54))
        else
          ...friends.invites.map((i) => ListTile(
                leading: const Icon(Icons.mail),
                title: Text('@${i.fromUsername}'),
                subtitle: Text(i.fromDisplayName),
                trailing: ElevatedButton(onPressed: () => friends.acceptInvite(i.fromUsername), child: const Text('Accept')),
              )),

        const SizedBox(height: 20),
        const Text('Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (friends.friends.isEmpty)
          const Text('No friends yet. Send a friend request by username.', style: TextStyle(color: Colors.white54))
        else
          ...friends.friends.map((f) => ListTile(
                leading: const Icon(Icons.person),
                title: Text('@${f.username}'),
                subtitle: Text(f.displayName),
                trailing: FilledButton.tonal(
                  onPressed: friends.activeRoomId != null ? null : () async {
                    final err = await friends.requestListenTogether(f.username);
                    if (mounted) setState(() => _msg = err ?? 'Listen request sent to @${f.username}');
                  },
                  child: const Text('Listen together'),
                ),
              )),
        const SizedBox(height: 12),
        const Text(
          'Send a listen request to a friend. When they accept, songs you play sync to both in real time. Tap Disconnect to go back to listening alone.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
