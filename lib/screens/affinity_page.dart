import 'package:flutter/material.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/data/place_repository.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/social/social_place_rating.dart';
import 'package:my_map_app/social/taste_affinity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A separate, explainable view of the taste signals shared with one accepted
/// friend. Place sheets stay focused on the place itself.
class AffinityPage extends StatefulWidget {
  const AffinityPage({
    required this.friendId,
    required this.friendName,
    required this.friendHandle,
    super.key,
  });

  final String friendId;
  final String friendName;
  final String friendHandle;

  @override
  State<AffinityPage> createState() => _AffinityPageState();
}

class _AffinityPageState extends State<AffinityPage> {
  bool _isLoading = true;
  String? _message;
  TasteAffinity? _affinity;

  @override
  void initState() {
    super.initState();
    _loadAffinity();
  }

  Future<void> _loadAffinity() async {
    final viewer = SocialConfig.client.auth.currentUser;
    if (viewer == null) {
      setState(() {
        _isLoading = false;
        _message = 'Sign in before viewing affinity.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final profileRows = await SocialConfig.client
          .from('profiles')
          .select('id, share_ratings_with_friends')
          .inFilter('id', [viewer.id, widget.friendId]);
      final sharesRatings = {
        for (final row in profileRows)
          row['id'] as String: row['share_ratings_with_friends'] == true,
      };
      if (sharesRatings[viewer.id] != true) {
        _setMessage(
          'Turn on “Share ratings with accepted friends” in your Account to calculate affinity.',
        );
        return;
      }
      if (sharesRatings[widget.friendId] != true) {
        _setMessage(
          '${widget.friendName} has not chosen to share ratings with accepted friends yet.',
        );
        return;
      }

      final ownRows = await SocialConfig.client
          .from('place_ratings')
          .select('place_id, rating, rating_details')
          .eq('user_id', viewer.id);
      final friendRows = await SocialConfig.client
          .from('place_ratings')
          .select('place_id, rating, rating_details')
          .eq('user_id', widget.friendId);
      final places = await const PlaceRepository().loadPlaces();
      final affinity = const TasteAffinityCalculator().calculate(
        first: TasteProfile(
          memberId: viewer.id,
          ratings: _ratingsFromRows(ownRows),
        ),
        second: TasteProfile(
          memberId: widget.friendId,
          ratings: _ratingsFromRows(friendRows),
        ),
        placesById: {for (final place in places) place.id: place},
      );
      if (!mounted) return;
      setState(() => _affinity = affinity);
    } on PostgrestException catch (error) {
      _setMessage(error.message);
    } catch (_) {
      _setMessage('Could not calculate affinity. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SocialPlaceRating> _ratingsFromRows(List<dynamic> rows) {
    return rows.map((row) {
      final rawDetails = row['rating_details'];
      final details = <String, int>{};
      if (rawDetails is Map) {
        for (final entry in rawDetails.entries) {
          if (entry.key is String && entry.value is num) {
            details[entry.key as String] = (entry.value as num).toInt();
          }
        }
      }
      return SocialPlaceRating(
        placeId: row['place_id'] as String,
        rating: (row['rating'] as num).toInt(),
        ratingDetails: details,
      );
    }).toList(growable: false);
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taste affinity'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAffinity,
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
                _FriendHeading(
                  name: widget.friendName,
                  handle: widget.friendHandle,
                ),
                const SizedBox(height: 22),
                if (_message != null)
                  _AffinityMessage(message: _message!)
                else if (_affinity != null)
                  _AffinityContent(affinity: _affinity!),
              ],
            ),
    );
  }
}

class _FriendHeading extends StatelessWidget {
  const _FriendHeading({required this.name, required this.handle});

  final String name;
  final String handle;

  @override
  Widget build(BuildContext context) {
    final visibleName = name.trim().isEmpty ? '@$handle' : name;
    final initial = visibleName.substring(0, 1).toUpperCase();
    return Row(
      children: [
        CircleAvatar(radius: 26, child: Text(initial)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visibleName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text('@$handle'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AffinityMessage extends StatelessWidget {
  const _AffinityMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF5FB),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.insights_outlined, size: 32),
            const SizedBox(height: 10),
            Text(
              'Affinity needs shared experiences',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _AffinityContent extends StatelessWidget {
  const _AffinityContent({required this.affinity});

  final TasteAffinity affinity;

  @override
  Widget build(BuildContext context) {
    if (affinity.score == null) {
      return const _AffinityMessage(
        message:
            'Rate some of the same places before comparing your tastes. Your place sheets stay private until both people enable sharing.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlobalAffinityCard(affinity: affinity),
        const SizedBox(height: 18),
        Text(
          'What this means',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(_insightFor(affinity)),
        const SizedBox(height: 22),
        Text(
          'Taste details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        _DimensionCard(label: 'Overall', dimension: affinity.overall),
        _DimensionCard(label: 'Food', dimension: affinity.food),
        _DimensionCard(label: 'Location', dimension: affinity.location),
        _DimensionCard(label: 'Service', dimension: affinity.service),
        _DimensionCard(label: 'Value for money', dimension: affinity.value),
      ],
    );
  }

  String _insightFor(TasteAffinity affinity) {
    final dimensions = affinity.details
        .where((dimension) => dimension.score != null)
        .toList(growable: false);
    if (dimensions.isEmpty) {
      return 'You often give similar overall ratings. Add optional food, location, service or value ratings to understand why.';
    }

    dimensions.sort((first, second) => second.score!.compareTo(first.score!));
    final strongest = dimensions.first;
    final weakest = dimensions.last;
    final strongestLabel = _labelFor(strongest.id);
    final weakestLabel = _labelFor(weakest.id);
    if (strongest.id != weakest.id &&
        strongest.score! >= 80 &&
        weakest.score! <= 60) {
      return 'You often give similar overall ratings and agree on $strongestLabel, but your views differ on $weakestLabel.';
    }
    if (affinity.overall.score != null && affinity.overall.score! >= 80) {
      return 'You often give similar overall ratings. Your strongest shared signal is $strongestLabel.';
    }
    return 'Your tastes vary across shared places. $strongestLabel is your closest common signal; $weakestLabel is the most different.';
  }

  String _labelFor(String id) => switch (id) {
        'food' => 'food',
        'location' => 'location',
        'service' => 'service',
        'value' => 'value for money',
        _ => 'overall ratings',
      };
}

class _GlobalAffinityCard extends StatelessWidget {
  const _GlobalAffinityCard({required this.affinity});

  final TasteAffinity affinity;

  @override
  Widget build(BuildContext context) {
    final status = affinity.isReliable ? 'Reliable' : 'Preliminary';
    return Card(
      elevation: 0,
      color: const Color(0xFF137DB8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taste match',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${affinity.score}%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$status · ${affinity.sharedRatedPlaces} places in common',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Evidence ${affinity.confidence}% — more shared ratings make this result stronger.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.86)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({required this.label, required this.dimension});

  final String label;
  final TasteAffinityDimension dimension;

  @override
  Widget build(BuildContext context) {
    final score = dimension.score;
    final subtitle = score == null
        ? 'No shared detail yet'
        : '$score% · ${dimension.comparedPlaces} shared ratings · ${dimension.evidenceLabel}';
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.auto_graph_rounded),
        title: Text(label),
        subtitle: Text(subtitle),
        trailing: score == null
            ? null
            : Text('$score%', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
