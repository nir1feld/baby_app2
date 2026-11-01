import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart';

import 'google_sheets_event_log.dart';
import 'remote_event_log.dart';
import 'sync_account.dart';

/// Signs in with Google and connects to Google Sheets.
class GoogleSheetsAccount implements SyncAccount {
  GoogleSheetsAccount({required this._webClientId});

  static const _scopes = [SheetsApi.spreadsheetsScope];
  static const _timeout = Duration(seconds: 30);

  final String _webClientId;
  GoogleSignInAccount? _user;
  bool _initialized = false;

  @override
  String? get email => _user?.email;

  Future<void> _initialize() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  @override
  Future<void> restore() async {
    if (_webClientId.isEmpty) return;
    await _initialize();
    _user = await GoogleSignIn.instance.attemptLightweightAuthentication();
  }

  @override
  Future<void> signIn() async {
    if (_webClientId.isEmpty) {
      throw const SyncException(
        "Google setup isn't finished: googleWebClientId is empty.",
      );
    }
    await _initialize();
    try {
      final user = await GoogleSignIn.instance.authenticate();
      await user.authorizationClient.authorizeScopes(_scopes);
      _user = user;
    } on GoogleSignInException catch (error) {
      throw SyncException(_explainSignIn(error));
    }
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _user = null;
  }

  @override
  Future<T> withLog<T>(
    String spreadsheetId,
    Future<T> Function(RemoteEventLog log) action,
  ) async {
    final user = _user;
    if (user == null) throw const SyncException('Please sign in.');

    final authorizer = user.authorizationClient;
    String? accessToken;
    try {
      // Tokens don't refresh themselves, so each sync asks for a current one.
      final authorization = await authorizer.authorizationForScopes(_scopes);
      if (authorization == null) {
        throw const SyncException('Please sign in again.');
      }
      accessToken = authorization.accessToken;

      final client = authorization.authClient(scopes: _scopes);
      try {
        final log = GoogleSheetsEventLog(SheetsApi(client), spreadsheetId);
        return await action(log).timeout(_timeout);
      } finally {
        client.close();
      }
    } on SyncException {
      rethrow;
    } on DetailedApiRequestError catch (error) {
      if (error.status == 401 && accessToken != null) {
        await authorizer.clearAuthorizationToken(accessToken: accessToken);
      }
      throw SyncException(_explainApiError(error));
    } on Exception {
      throw const SyncException(
        "Couldn't reach Google. Your logs are safe on this phone and will "
        'sync later.',
      );
    }
  }

  String _explainSignIn(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        "Sign-in was cancelled. If you didn't cancel it, check the app's "
            'package name and SHA-1 in Google Cloud.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google setup problem: check the client IDs and SHA-1 in Google '
            'Cloud.',
      _ => 'Sign-in failed: ${error.description ?? error.code.name}',
    };
  }

  String _explainApiError(DetailedApiRequestError error) {
    return switch (error.status) {
      401 => 'Please sign in again.',
      403 =>
        'No access to this sheet. Ask its owner to share it with $email as '
            'an editor.',
      404 => 'Sheet not found. Check the link.',
      429 => 'Google is limiting requests. Sync will try again later.',
      _ => 'Google Sheets error: ${error.message ?? error.status}',
    };
  }
}
