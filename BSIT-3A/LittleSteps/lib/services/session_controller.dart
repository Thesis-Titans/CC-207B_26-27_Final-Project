import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// A controller for managing the app's session.
class SessionController extends ChangeNotifier {
  /// The constructor that
  /// creates a session that shares [apiClient] across the app
  SessionController({ApiClient? apiClient})
    : apiClient = apiClient ?? ApiClient();

  /// The single API client that every screen and service uses
  final ApiClient apiClient;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  ///SIGNS IN the caregiver and attaches [idToken] to every API request.
  void signIn(String idToken) {
    apiClient.setAuthToken(idToken); // sets the token in the API client
    _isSignedIn = true;

    /// this checks whether a caregiver is currently signed in.
    notifyListeners(); //tells listeners
  }

  /// SIGNS OUT the caregiver and CLEARS the auth token from the API client.
  void signOut() {
    apiClient.setAuthToken(null); // clears the token in the API client
    _isSignedIn = false; // sets _isSignedIn to false
    notifyListeners(); // tells listeners
  }
}
