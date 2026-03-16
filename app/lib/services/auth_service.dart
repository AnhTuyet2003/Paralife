import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), // ✅ Trim whitespace
        password: password.trim(),
      );
      
      return userCredential;
      
    } on FirebaseAuthException catch (e) {
      
      // ✅ CUSTOM ERROR MESSAGES
      String errorMessage;
      
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ';
          break;
        case 'user-disabled':
          errorMessage = 'Tài khoản đã bị vô hiệu hóa';
          break;
        case 'user-not-found':
          errorMessage = 'Tài khoản không tồn tại. Vui lòng đăng ký';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'Email hoặc mật khẩu không đúng';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều lần thử. Vui lòng thử lại sau';
          break;
        default:
          errorMessage = 'Lỗi đăng nhập: ${e.message}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }

  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      
      // 1. Tạo tài khoản Firebase
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // 2. Cập nhật display name
      await userCredential.user?.updateDisplayName(fullName);
      await userCredential.user?.reload();
      
      
      return _auth.currentUser;
      
    } on FirebaseAuthException catch (e) {
      
      String errorMessage;
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email đã được sử dụng. Vui lòng đăng nhập';
          break;
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ';
          break;
        case 'weak-password':
          errorMessage = 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
          break;
        default:
          errorMessage = 'Lỗi đăng ký: ${e.message}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      return userCredential.user;
      
    } catch (e) {
      throw Exception('Lỗi đăng nhập Google: $e');
    }
  }

  // ✅ SEND PASSWORD RESET EMAIL
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      
      await _auth.sendPasswordResetEmail(email: email.trim());
      
    } on FirebaseAuthException catch (e) {
      
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Email không tồn tại trong hệ thống';
          break;
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều yêu cầu. Vui lòng thử lại sau';
          break;
        default:
          errorMessage = 'Lỗi gửi email: ${e.message}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}