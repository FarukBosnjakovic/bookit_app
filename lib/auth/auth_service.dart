import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── Sign up (regular user) ─────────────────────────────────────────
  Future<String?> signUpUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': '',
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      await credential.user!.sendEmailVerification();
      await _auth.signOut();

      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (e) {
      return 'Došlo je do greške. Pokušajte ponovo.';
    }
  }

  // ── Sign up (manager) ──────────────────────────────────────────────
  Future<String?> signUpManager({
    required String name,
    required String email,
    required String password,
    required String restaurantName,
    required String restaurantAddress,
    required String restaurantPhone,
    required String city,
    required List<String> cuisines,
    required int tableCount,
    required List<Map<String, dynamic>> sections, // ← new
    required Map<String, Map<String, dynamic>> workingHours,
    required String description,
    required String registrationCode,
    double? lat,
    double? lng,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final restaurantRef = _firestore.collection('restaurants').doc();
      await restaurantRef.set({
        'id': restaurantRef.id,
        'name': restaurantName,
        'address': restaurantAddress,
        'phone': restaurantPhone,
        'city': city,
        'email': email,
        'cuisines': cuisines,
        'lat': lat,
        'lng': lng,
        'description': description,
        'workingHours': workingHours,
        'tableCount': tableCount,   // total across all sections
        'sections': sections,       // ← list of {id, name, tables}
        'rating': 0.0,
        'reviewCount': 0,
        'imageUrl': '',
        'isOpen': false,
        'managerId': credential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'name': name,
        'email': email,
        'phone': '',
        'photoUrl': '',
        'role': 'manager',
        'status': 'pending',
        'restaurantId': restaurantRef.id,
        'registrationCode': registrationCode,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      await credential.user!.sendEmailVerification();
      await _auth.signOut();

      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (e) {
      return 'Došlo je do greške. Pokušajte ponovo.';
    }
  }

  // ── Login ──────────────────────────────────────────────────────────
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!credential.user!.emailVerified) {
        await _auth.signOut();
        return 'email-not-verified';
      }

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .update({'lastLoginAt': FieldValue.serverTimestamp()});

      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (e) {
      return 'Došlo je do greške. Pokušajte ponovo.';
    }
  }

  // ── Resend verification email ──────────────────────────────────────
  Future<String?> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.sendEmailVerification();
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (e) {
      return 'Došlo je do greške. Pokušajte ponovo.';
    }
  }

  // ── Check email verified ───────────────────────────────────────────
  Future<bool> checkEmailVerified({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (!verified) await _auth.signOut();
      return verified;
    } catch (_) {
      return false;
    }
  }

  // ── Forgot password ────────────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Get current user data ──────────────────────────────────────────
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc =
        await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // ── Get current user ID ────────────────────────────────────────────
  Future<String?> getCurrentUserId() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // -- Sign In with Google
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) return 'Prijava otkazana.';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;

      if (user == null) return 'Greška pri prijavi.';

      // Create Firestore doc if it's first time
      final doc = await FirebaseFirestore.instance 
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phone': '',
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
      }
      return null;
    } catch (e) {
      return 'Greška: ${e.toString()}';
    }
  }

  // -- Sign In with Apple
  Future<String?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = result.user;

      if (user == null) return 'Greška pri prijavi.';

      final doc = await FirebaseFirestore.instance 
          .collection('users')
          .doc(user.uid)
          .get();
      
      if(!doc.exists) {
        final fullName = [appleCredential.givenName, appleCredential.familyName]
          .where((e) => e != null)
          .join(' ');
      
        await FirebaseFirestore.instance 
            .collection('users')
            .doc(user.uid)
            .set({
              'name': fullName,
              'email': user.email ?? '',
              'phone': '',
              'role': 'user',
              'createdAt': FieldValue.serverTimestamp(),
            });
      }
      return null;
    } catch (e) {
      return 'Greška: ${e.toString()}';
    }
  }

  // ── Auth state stream ──────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Error messages ─────────────────────────────────────────────────
  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ovaj email je već registrovan.';
      case 'invalid-email':
        return 'Email adresa nije ispravna.';
      case 'weak-password':
        return 'Lozinka mora imati najmanje 6 znakova.';
      case 'user-not-found':
        return 'Ne postoji nalog sa ovim emailom.';
      case 'wrong-password':
        return 'Pogrešna lozinka. Pokušajte ponovo.';
      case 'too-many-requests':
        return 'Previše pokušaja. Pokušajte ponovo kasnije.';
      case 'network-request-failed':
        return 'Nema internet konekcije.';
      default:
        return 'Došlo je do greške. Pokušajte ponovo.';
    }
  }
}