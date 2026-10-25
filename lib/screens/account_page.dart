import 'package:flutter/material.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _handleController = TextEditingController();
  final _displayNameController = TextEditingController();

  User? _user;
  bool _shareRatings = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (SocialConfig.isAvailable) {
      _loadProfile();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _handleController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SocialConfig.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _user = null);
        return;
      }

      final profile = await SocialConfig.client
          .from('profiles')
          .select('handle, display_name, share_ratings_with_friends')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;

      _handleController.text = profile?['handle'] as String? ?? '';
      _displayNameController.text =
          profile?['display_name'] as String? ?? '';
      setState(() {
        _user = user;
        _shareRatings = profile?['share_ratings_with_friends'] == true;
      });
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not load your profile. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await SocialConfig.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _loadProfile();
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not sign in. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signUp() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final response = await SocialConfig.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session == null) {
        _showMessage('Check your email to confirm the new account.');
      } else {
        await _loadProfile();
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not create the account. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (user == null || _isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      await SocialConfig.client.from('profiles').upsert({
        'id': user.id,
        'handle': _handleController.text.trim().toLowerCase(),
        'display_name': _displayNameController.text.trim(),
        'share_ratings_with_friends': _shareRatings,
      }, onConflict: 'id');
      _showMessage('Profile saved.');
    } on PostgrestException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not save the profile. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSaving = true);
    try {
      await SocialConfig.client.auth.signOut();
      _handleController.clear();
      _displayNameController.clear();
      if (mounted) {
        setState(() {
          _user = null;
          _shareRatings = false;
        });
      }
    } catch (_) {
      _showMessage('Could not sign out. Try again.');
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
    if (!SocialConfig.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: _AccountInfoCard(
            title: 'Social features are not connected yet',
            message:
                'The map works normally. Add the local Supabase configuration when you are ready to enable accounts and friends.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_user == null) _buildSignInForm(context) else _buildProfile(context),
              ],
            ),
    );
  }

  Widget _buildSignInForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join My Locals',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an account to add friends and share recommendations only with people you approve.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: _validatePassword,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _signIn,
              child: Text(_isSaving ? 'Please wait…' : 'Sign in'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _signUp,
              child: const Text('Create account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(_user!.email ?? ''),
          const SizedBox(height: 24),
          TextFormField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: _validateDisplayName,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _handleController,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Username',
              helperText: '3–24 lowercase letters, numbers or underscores.',
            ),
            validator: _validateHandle,
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _shareRatings,
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _shareRatings = value),
            title: const Text('Share ratings with accepted friends'),
            subtitle: const Text(
              'Turn this on only when you want affinity and recommendations to use your ratings.',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: Text(_isSaving ? 'Saving…' : 'Save profile'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isSaving ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.people_outline_rounded, size: 36),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email.';
  }
  return null;
}

String? _validatePassword(String? value) {
  if ((value ?? '').length < 8) {
    return 'Use at least 8 characters.';
  }
  return null;
}

String? _validateDisplayName(String? value) {
  if ((value?.trim().length ?? 0) < 2) {
    return 'Use at least 2 characters.';
  }
  return null;
}

String? _validateHandle(String? value) {
  final handle = value?.trim() ?? '';
  if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(handle)) {
    return 'Use 3–24 lowercase letters, numbers or underscores.';
  }
  return null;
}
