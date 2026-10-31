import 'package:flutter/material.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/models/place.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores a member's own experience separately from the curated rating in the
/// local dataset. A member chooses whether this rating may later be used with
/// accepted friends through their profile privacy setting.
class PersonalPlaceRatingCard extends StatefulWidget {
  const PersonalPlaceRatingCard({required this.place, super.key});

  final Place place;

  @override
  State<PersonalPlaceRatingCard> createState() =>
      _PersonalPlaceRatingCardState();
}

class _PersonalPlaceRatingCardState extends State<PersonalPlaceRatingCard> {
  final _noteController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  int? _rating;
  bool _isRecommended = false;

  User? get _user =>
      SocialConfig.isAvailable ? SocialConfig.client.auth.currentUser : null;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadRating() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final row = await SocialConfig.client
          .from('place_ratings')
          .select('rating, note, is_recommended')
          .eq('user_id', user.id)
          .eq('place_id', widget.place.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _rating = (row?['rating'] as num?)?.toInt();
        _noteController.text = row?['note'] as String? ?? '';
        _isRecommended = row?['is_recommended'] == true;
      });
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not load your rating. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRating() async {
    final user = _user;
    final rating = _rating;
    if (user == null || rating == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await SocialConfig.client.from('place_ratings').upsert({
        'user_id': user.id,
        'place_id': widget.place.id,
        'rating': rating,
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'is_recommended': _isRecommended,
      }, onConflict: 'user_id,place_id');
      _showMessage('Your rating was saved.');
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not save your rating. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    if (!SocialConfig.isAvailable) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: const Color(0xFFEAF5FB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const _PersonalRatingMessage(
                title: 'Your experience',
                message: 'Sign in from Account to keep a private rating here.',
              )
            : _isLoading
            ? const SizedBox(
                height: 54,
                child: Center(child: CircularProgressIndicator()),
              )
            : _rating == null
            ? _PersonalRatingEmpty(onStart: () => setState(() => _rating = 7))
            : _PersonalRatingEditor(
                rating: _rating!,
                isRecommended: _isRecommended,
                noteController: _noteController,
                isSaving: _isSaving,
                onRatingChanged: (value) => setState(() => _rating = value),
                onRecommendedChanged: (value) =>
                    setState(() => _isRecommended = value),
                onSave: _saveRating,
              ),
      ),
    );
  }
}

class _PersonalRatingMessage extends StatelessWidget {
  const _PersonalRatingMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 5),
        Text(message),
      ],
    );
  }
}

class _PersonalRatingEmpty extends StatelessWidget {
  const _PersonalRatingEmpty({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your experience',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Keep your own 1–10 rating after you have visited this place. It does not change the curated map rating.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Rate this place'),
        ),
      ],
    );
  }
}

class _PersonalRatingEditor extends StatelessWidget {
  const _PersonalRatingEditor({
    required this.rating,
    required this.isRecommended,
    required this.noteController,
    required this.isSaving,
    required this.onRatingChanged,
    required this.onRecommendedChanged,
    required this.onSave,
  });

  final int rating;
  final bool isRecommended;
  final TextEditingController noteController;
  final bool isSaving;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<bool> onRecommendedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your experience',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            _RatingBadge(rating: rating),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Private by default. Separate from the curated map rating.'),
        Slider(
          value: rating.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$rating/10',
          onChanged: isSaving ? null : (value) => onRatingChanged(value.round()),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isRecommended,
          onChanged: isSaving ? null : onRecommendedChanged,
          title: const Text('Recommend it'),
          subtitle: const Text(
            'Used later for friends who can see your shared ratings.',
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: noteController,
          enabled: !isSaving,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Private note (optional)',
            hintText: 'What made this place worth remembering?',
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.bookmark_added_outlined),
            label: Text(isSaving ? 'Saving…' : 'Save your rating'),
          ),
        ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF6A800), size: 18),
          const SizedBox(width: 4),
          Text('$rating/10', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
