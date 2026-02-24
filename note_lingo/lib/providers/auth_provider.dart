// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();
  final FirestoreService _db = FirestoreService();

  // ── State ────────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  UserModel? _profile;
  UserModel? get profile => _profile;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) _loadProfile(user.uid);
      notifyListeners();
    });
  }

  // ── Onboarding flag ──────────────────────────────────────────
  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefSeenOnboarding) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefSeenOnboarding, true);
  }

  // ── Load Firestore profile ───────────────────────────────────
  Future<void> _loadProfile(String uid) async {
    try {
      _profile = await _db.getUserProfile(uid);
      notifyListeners();
    } catch (_) {}
  }

  // ── Email / Password Sign In ─────────────────────────────────
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _loadProfile(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw _readable(e);
    } finally {
      _setLoading(false);
    }
  }

  // ── Email / Password Register ────────────────────────────────
  Future<void> register(
    String email,
    String password,
    String name,
    String role,
  ) async {
    _setLoading(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Set display name on Auth user
      await cred.user?.updateDisplayName(name.trim());

      // Create Firestore profile
      final profile = UserModel(
        uid: cred.user!.uid,
        name: name.trim(),
        email: email.trim(),
        role: role,
        createdAt: DateTime.now(),
      );
      await _db.createUserProfile(profile);
      _profile = profile;
    } on FirebaseAuthException catch (e) {
      throw _readable(e);
    } finally {
      _setLoading(false);
    }
  }

  // ── Google Sign In ───────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        throw 'Google sign-in cancelled.';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user!;

      // Create Firestore profile if first time
      final existing = await _db.getUserProfile(user.uid);
      if (existing == null) {
        final profile = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          role: 'Student',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _db.createUserProfile(profile);
        _profile = profile;
      } else {
        _profile = existing;
      }
    } on FirebaseAuthException catch (e) {
      throw _readable(e);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Forgot Password ──────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _readable(e);
    }
  }

  // ── Update Profile ───────────────────────────────────────────
  Future<void> updateProfile({String? name, String? role}) async {
    if (currentUser == null) return;
    _setLoading(true);
    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        await currentUser!.updateDisplayName(name);
        updates['name'] = name;
      }
      if (role != null) updates['role'] = role;
      if (updates.isNotEmpty) {
        await _db.updateUserProfile(updates);
        _profile = _profile?.copyWith(name: name, role: role);
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
    // ignore: body_might_complete_normally_catch_error
    await _google.signOut().catchError((_) {});
    _profile = null;
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
