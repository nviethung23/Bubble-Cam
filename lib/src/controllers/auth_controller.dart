import 'package:get/get.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _auth;
  AuthController(this._auth);

  RxBool loading = false.obs;

  Future<void> signInEmail(String email, String pass) async {
    loading.value = true;
    try {
      await _auth.signInWithEmail(email, pass);
    } finally {
      loading.value = false;
    }
  }

  Future<void> signUpEmail(String email, String pass) async {
    loading.value = true;
    try {
      await _auth.signUpWithEmail(email, pass);
    } finally {
      loading.value = false;
    }
  }

  Future<void> signInGoogle() async {
    loading.value = true;
    try {
      await _auth.signInWithGoogle();
    } finally {
      loading.value = false;
    }
  }

  Future<void> signOut() => _auth.signOut();

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;
}
