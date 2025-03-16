import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _codeSent = false;
  bool _codeVerified = false;
  String _userId = '';
  String _resetToken = '';

  // API URL - Bu URL'yi kendi backend URL'niz ile değiştirin
  final String apiUrl =
      'https://3000-idx-flutter-1740770618502.cluster-6yqpn75caneccvva7hjo4uejgk.cloudworkstations.dev/api/password';

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  // Şifre sıfırlama kodu gönderme
  Future<void> _sendResetCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Backend'e istek gönder
      final response = await http.post(
        Uri.parse('$apiUrl/send-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _emailController.text.trim()}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _codeSent = true;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Şifre sıfırlama kodu email adresinize gönderildi.',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Firebase şifre sıfırlama e-postası gönderme işlemi kaldırıldı
          // Artık sadece API üzerinden 6 haneli kod gönderiliyor
        }
      } else {
        if (mounted) {
          // Hata mesajını göster
          String errorMessage = responseData['message'] ?? 'Bir hata oluştu';

          // 404 hatası için özel mesaj
          if (response.statusCode == 404) {
            errorMessage =
                'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı. Lütfen kayıtlı e-posta adresinizi girin.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Tamam',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Şifre sıfırlama kodunu doğrulama
  Future<void> _verifyResetCode() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 6 haneli kodu girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Backend'e istek gönder
      final response = await http.post(
        Uri.parse('$apiUrl/verify-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'code': _codeController.text.trim(),
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _codeVerified = true;
            _userId = responseData['userId'];
            _resetToken = responseData['resetToken'];
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kod doğrulandı. Şimdi yeni şifrenizi belirleyin.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Bir hata oluştu'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Şifre sıfırlama
  Future<void> _resetPassword() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen yeni şifrenizi girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreler eşleşmiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Backend'e istek gönder
      final response = await http.post(
        Uri.parse('$apiUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _userId,
          'resetToken': _resetToken,
          'newPassword': _passwordController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Şifreniz başarıyla sıfırlandı. Giriş yapabilirsiniz.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // Giriş sayfasına dön
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Bir hata oluştu'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple.shade100,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.purple.shade700),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Şifre Sıfırlama',
          style: TextStyle(color: Colors.purple.shade700),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade50, Colors.purple.shade100],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                              'Şifre Sıfırlama',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .slideY(begin: -0.5, end: 0),
                        const SizedBox(height: 24),

                        // Email girişi
                        if (!_codeSent)
                          Column(
                            children: [
                              Text(
                                'Kayıtlı email adresinizi girin.\nŞifre sıfırlama kodu göndereceğiz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ).animate().fadeIn(
                                delay: 200.ms,
                                duration: 500.ms,
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.email,
                                        color: Colors.purple.shade500,
                                      ),
                                      labelText: 'Email',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.purple.shade500,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Email boş bırakılamaz';
                                      }
                                      if (!_isValidEmail(value)) {
                                        return 'Geçerli bir email adresi giriniz';
                                      }
                                      return null;
                                    },
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 500.ms)
                                  .slideX(begin: -0.1, end: 0),
                            ],
                          ),

                        // Kod girişi
                        if (_codeSent && !_codeVerified)
                          Column(
                            children: [
                              Text(
                                'Email adresinize gönderilen 6 haneli kodu girin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ).animate().fadeIn(
                                delay: 200.ms,
                                duration: 500.ms,
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                    controller: _codeController,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.lock,
                                        color: Colors.purple.shade500,
                                      ),
                                      labelText: 'Doğrulama Kodu',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.purple.shade500,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 500.ms)
                                  .slideX(begin: -0.1, end: 0),
                              const SizedBox(height: 16),
                              Text(
                                'Not: Ayrıca e-posta adresinize gönderilen şifre sıfırlama bağlantısını da kullanabilirsiniz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ).animate().fadeIn(
                                delay: 400.ms,
                                duration: 500.ms,
                              ),
                            ],
                          ),

                        // Şifre girişi
                        if (_codeVerified)
                          Column(
                            children: [
                              Text(
                                'Yeni şifrenizi belirleyin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ).animate().fadeIn(
                                delay: 200.ms,
                                duration: 500.ms,
                              ),
                              const SizedBox(height: 32),
                              TextFormField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.lock,
                                        color: Colors.purple.shade500,
                                      ),
                                      labelText: 'Yeni Şifre',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.purple.shade500,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    obscureText: true,
                                  )
                                  .animate()
                                  .fadeIn(delay: 300.ms, duration: 500.ms)
                                  .slideX(begin: -0.1, end: 0),
                              const SizedBox(height: 16),
                              TextFormField(
                                    controller: _confirmPasswordController,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.lock,
                                        color: Colors.purple.shade500,
                                      ),
                                      labelText: 'Şifreyi Tekrar Girin',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.purple.shade500,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    obscureText: true,
                                  )
                                  .animate()
                                  .fadeIn(delay: 400.ms, duration: 500.ms)
                                  .slideX(begin: -0.1, end: 0),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Butonlar
                        _isLoading
                            ? CircularProgressIndicator(
                              color: Colors.purple.shade500,
                            )
                            : ElevatedButton(
                                  onPressed: () {
                                    if (!_codeSent) {
                                      _sendResetCode();
                                    } else if (!_codeVerified) {
                                      _verifyResetCode();
                                    } else {
                                      _resetPassword();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade500,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      double.infinity,
                                      50,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: Text(
                                    !_codeSent
                                        ? 'Şifre Sıfırlama'
                                        : !_codeVerified
                                        ? 'Kodu Doğrula'
                                        : 'Şifreyi Sıfırla',
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 400.ms, duration: 500.ms)
                                .slideY(begin: 0.1, end: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
