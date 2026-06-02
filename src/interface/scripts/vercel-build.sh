#!/usr/bin/env bash
set -euo pipefail

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    return
  fi

  local channel="${FLUTTER_CHANNEL:-stable}"
  local root="${FLUTTER_ROOT:-$HOME/flutter}"

  if [ ! -d "$root/.git" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b "$channel" "$root"
  fi

  export PATH="$root/bin:$PATH"
}

build_with_vercel_env() {
  local -a required_keys=(
    API_BASE_URL
    SUPABASE_ANON_KEY
    SUPABASE_URL
  )
  local -a define_keys=(
    APP_ENV
    API_BASE_URL
    SUPABASE_ANON_KEY
    SUPABASE_URL
    GOOGLE_WEB_CLIENT_ID
    OAUTH_REDIRECT_SCHEME
    OAUTH_REDIRECT_HOST
  )
  local -a missing=()
  local -a dart_defines=()

  for key in "${required_keys[@]}"; do
    if [ -z "${!key-}" ]; then
      missing+=("$key")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing Vercel environment variables: %s\n' "${missing[*]}" >&2
    exit 1
  fi

  if [ -z "${APP_ENV-}" ]; then
    dart_defines+=(--dart-define=APP_ENV=production)
  fi

  for key in "${define_keys[@]}"; do
    if [ -n "${!key-}" ]; then
      dart_defines+=(--dart-define="$key=${!key}")
    fi
  done

  flutter build web --release "${dart_defines[@]}"
}

ensure_flutter
flutter config --enable-web
flutter pub get

if [ -f .prod.env ]; then
  flutter build web --release --dart-define-from-file=.prod.env
else
  build_with_vercel_env
fi
