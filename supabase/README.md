# Supabase setup for My Locals

This folder is intentionally safe to commit: it contains the database design,
never an API key or a password.

## When you are ready to activate social features

1. Create one Supabase project in your own account.
2. In its SQL Editor, run the migration in `migrations/`.
3. Copy the project URL and the **publishable** key into a local configuration
   file when the Flutter client is connected. Do not commit that file and never
   use the service-role key in the app.
4. Test account creation, a friend request and a private rating with two test
   accounts before inviting real friends.

The migration creates no public review feed. Ratings can be read only by their
owner, or by an accepted friend when the owner has explicitly enabled sharing.
