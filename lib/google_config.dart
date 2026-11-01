/// The "Web client" ID from your Google Cloud project's OAuth credentials.
/// It's read from the git-ignored google_config.json at build time, using
/// --dart-define-from-file. See the README.
/// While this is empty, the app runs normally but can't sign in or sync.
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
