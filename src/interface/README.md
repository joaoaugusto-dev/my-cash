# my_cash

A new Flutter project.

## Authentication Setup

Create a local `.env` file in this folder based on [.env.example](.env.example), then pass it with `--dart-define-from-file=.env`:

```env
APP_ENV=development
SUPABASE_URL=
SUPABASE_ANON_KEY=
API_BASE_URL=http://localhost:3000/api
GOOGLE_WEB_CLIENT_ID=
```

Hybrid auth setup:
- Web uses Supabase OAuth redirect on the same HTTP origin.
- Android uses native Google Sign-In and exchanges the `idToken` with Supabase.
- Keep the Google Web Client ID configured; Android uses it as `serverClientId`.
- In Supabase URL Configuration, keep `Site URL` as your web domain (never `mycash://...`).
- Keep only public client config here. Never put service role keys, JWT secrets, or provider secrets in Flutter env files.

Local development should point to the Supabase dev cloud project and the local API. Use `http://localhost:3000/api` for web and `http://10.0.2.2:3000/api` for the Android emulator.

For production builds, set `APP_ENV=production` and point `API_BASE_URL` to the deployed API. Production validation rejects local hosts and non-HTTPS API URLs:

```env
APP_ENV=production
API_BASE_URL=https://<api-production-domain>/api
```

Run the backend deployment from `src/api/my_cash` with `vercel --prod`, then build the web app with production `--dart-define` values instead of committing production `.env` files.

Run the app with:

```bash
flutter pub get
flutter run --dart-define-from-file=.env
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
