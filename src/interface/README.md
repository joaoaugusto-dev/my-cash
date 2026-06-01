# my_cash

A new Flutter project.

## Authentication Setup

Create a local `.env` file in this folder based on [.env.example](.env.example):

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
API_BASE_URL=http://localhost:3000/api
OAUTH_REDIRECT_SCHEME=mycash
OAUTH_REDIRECT_HOST=auth-callback
GOOGLE_WEB_CLIENT_ID=
```

Use `mycash://auth-callback` as the redirect URL in Supabase and configure the Google Web Client ID in the same `.env` file. On Android, the native Google login uses that Web Client ID as `serverClientId`.

For production builds, point `API_BASE_URL` to the deployed API, for example:

```env
API_BASE_URL=https://<your-vercel-deployment>.vercel.app/api
```

Run the backend deployment from `src/api/my_cash` with `vercel --prod`, then update the app `.env` before building the release artifact.

Run the app with:

```bash
flutter pub get
flutter run
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
