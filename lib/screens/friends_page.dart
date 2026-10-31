import 'package:flutter/material.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/screens/affinity_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A deliberately small first social surface: members can find a person by
/// username, send a request, and decide whether to accept incoming requests.
/// Ratings remain private until both people are friends and opt in separately.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isMutating = false;
  List<_Friendship> _friendships = const [];
  Map<String, _Person> _people = const {};
  List<_Person> _searchResults = const [];

  User? get _user =>
      SocialConfig.isAvailable ? SocialConfig.client.auth.currentUser : null;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rows = await SocialConfig.client
          .from('friendships')
          .select('id, requester_id, addressee_id, status, created_at')
          .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}')
          .order('created_at', ascending: false);
      final friendships = rows
          .map((row) => _Friendship.fromJson(row))
          .toList(growable: false);
      final personIds = friendships
          .map((friendship) => friendship.otherMemberId(user.id))
          .toSet()
          .toList(growable: false);

      var people = <String, _Person>{};
      if (personIds.isNotEmpty) {
        final profileRows = await SocialConfig.client
            .from('profiles')
            .select('id, handle, display_name')
            .inFilter('id', personIds);
        people = {
          for (final row in profileRows)
            (row['id'] as String): _Person.fromJson(row),
        };
      }

      if (!mounted) return;
      setState(() {
        _friendships = friendships;
        _people = people;
      });
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not load friends. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search() async {
    final user = _user;
    final query = _searchController.text.trim().toLowerCase();
    if (user == null || query.length < 3) {
      _showMessage('Enter at least 3 characters of a username.');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final rows = await SocialConfig.client
          .from('profiles')
          .select('id, handle, display_name')
          .ilike('handle', '$query%')
          .neq('id', user.id)
          .limit(8);
      if (!mounted) return;
      setState(() {
        _searchResults = rows.map((row) => _Person.fromJson(row)).toList();
      });
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not search for that username. Try again.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(_Person person) async {
    final user = _user;
    if (user == null || _isMutating) return;
    setState(() => _isMutating = true);
    try {
      await SocialConfig.client.from('friendships').insert({
        'requester_id': user.id,
        'addressee_id': person.id,
        'status': 'pending',
      });
      _showMessage('Friend request sent to @${person.handle}.');
      if (mounted) setState(() => _searchResults = const []);
      await _loadFriends();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        _showMessage('You already have a request or connection with this person.');
      } else {
        _showMessage(error.message);
      }
    } catch (_) {
      _showMessage('Could not send the request. Try again.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _respondToRequest(_Friendship friendship, String status) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await SocialConfig.client.from('friendships').update({
        'status': status,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', friendship.id);
      _showMessage(status == 'accepted' ? 'Friend request accepted.' : 'Request declined.');
      await _loadFriends();
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not update the request. Try again.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _cancelRequest(_Friendship friendship) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await SocialConfig.client.from('friendships').delete().eq('id', friendship.id);
      _showMessage('Friend request cancelled.');
      await _loadFriends();
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not cancel the request. Try again.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (!SocialConfig.isAvailable) {
      return const _FriendsInfoPage(
        title: 'Friends are not connected yet',
        message: 'Add the local Supabase configuration before using social features.',
      );
    }
    if (user == null) {
      return const _FriendsInfoPage(
        title: 'Sign in first',
        message: 'Create an account from Account before adding friends.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadFriends,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Find friends by username',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Requests are private. Ratings stay private until you both become friends and each person chooses to share them.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    suffixIcon: IconButton(
                      onPressed: _isSearching ? null : _search,
                      tooltip: 'Search',
                      icon: _isSearching
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._searchResults.map(
                    (person) => _PersonTile(
                      person: person,
                      trailing: FilledButton(
                        onPressed: _isMutating ? null : () => _sendRequest(person),
                        child: const Text('Add'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                _FriendshipSection(
                  title: 'Requests for you',
                  emptyMessage: 'No requests waiting for you.',
                  friendships: _incomingPending(user.id),
                  people: _people,
                  userId: user.id,
                  builder: (friendship, person) => _PersonTile(
                    person: person,
                    subtitle: 'Wants to connect with you',
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          onPressed: _isMutating
                              ? null
                              : () => _respondToRequest(friendship, 'accepted'),
                          tooltip: 'Accept',
                          icon: const Icon(Icons.check_rounded),
                        ),
                        IconButton(
                          onPressed: _isMutating
                              ? null
                              : () => _respondToRequest(friendship, 'declined'),
                          tooltip: 'Decline',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _FriendshipSection(
                  title: 'Your friends',
                  emptyMessage: 'Add a friend when you are ready.',
                  friendships: _accepted(),
                  people: _people,
                  userId: user.id,
                  builder: (_, person) => _PersonTile(
                    person: person,
                    subtitle: 'Open taste affinity',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AffinityPage(
                            friendId: person.id,
                            friendName: person.displayName,
                            friendHandle: person.handle,
                          ),
                        ),
                      );
                    },
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                _FriendshipSection(
                  title: 'Sent requests',
                  emptyMessage: 'No sent requests.',
                  friendships: _outgoingPending(user.id),
                  people: _people,
                  userId: user.id,
                  builder: (friendship, person) => _PersonTile(
                    person: person,
                    subtitle: 'Waiting for a response',
                    trailing: TextButton(
                      onPressed: _isMutating ? null : () => _cancelRequest(friendship),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<_Friendship> _incomingPending(String userId) => _friendships
      .where(
        (friendship) =>
            friendship.status == 'pending' && friendship.addresseeId == userId,
      )
      .toList(growable: false);

  List<_Friendship> _outgoingPending(String userId) => _friendships
      .where(
        (friendship) =>
            friendship.status == 'pending' && friendship.requesterId == userId,
      )
      .toList(growable: false);

  List<_Friendship> _accepted() => _friendships
      .where((friendship) => friendship.status == 'accepted')
      .toList(growable: false);
}

class _FriendshipSection extends StatelessWidget {
  const _FriendshipSection({
    required this.title,
    required this.emptyMessage,
    required this.friendships,
    required this.people,
    required this.userId,
    required this.builder,
  });

  final String title;
  final String emptyMessage;
  final List<_Friendship> friendships;
  final Map<String, _Person> people;
  final String userId;
  final Widget Function(_Friendship friendship, _Person person) builder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (friendships.isEmpty)
          Text(emptyMessage)
        else
          ...friendships.map((friendship) {
            final person = people[friendship.otherMemberId(userId)];
            if (person == null) return const SizedBox.shrink();
            return builder(friendship, person);
          }),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    this.subtitle,
    this.onTap,
    required this.trailing,
  });

  final _Person person;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final initials = person.displayName.trim().isEmpty
        ? person.handle.substring(0, 1).toUpperCase()
        : person.displayName.trim().substring(0, 1).toUpperCase();
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(child: Text(initials)),
        title: Text(person.displayName.trim().isEmpty ? '@${person.handle}' : person.displayName),
        subtitle: Text(subtitle ?? '@${person.handle}'),
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}

class _FriendsInfoPage extends StatelessWidget {
  const _FriendsInfoPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded, size: 44),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _Person {
  const _Person({
    required this.id,
    required this.handle,
    required this.displayName,
  });

  final String id;
  final String handle;
  final String displayName;

  factory _Person.fromJson(Map<String, dynamic> json) => _Person(
        id: json['id'] as String,
        handle: json['handle'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
      );
}

class _Friendship {
  const _Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final String status;

  String otherMemberId(String userId) =>
      requesterId == userId ? addresseeId : requesterId;

  factory _Friendship.fromJson(Map<String, dynamic> json) => _Friendship(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: json['status'] as String,
      );
}
