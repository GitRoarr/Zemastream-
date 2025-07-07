import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/user/auth_service.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import '../../data/models/user_model.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isObscured = true;
  bool _isLoading = false;
  String _role = 'listener';
  bool _isPasswordValid = false;
  String _passwordError = '';
  bool _isEmailValid = true;

  void _togglePasswordVisibility() => setState(() => _isObscured = !_isObscured);

  // Password validation logic
  void _validatePassword(String value) {
    if (value.isNotEmpty) {
      setState(() {
        _isPasswordValid = value.length >= 8 &&
            value.contains(RegExp(r'[A-Z]')) &&
            value.contains(RegExp(r'[a-z]')) &&
            value.contains(RegExp(r'[0-9]')) &&
            value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
        _passwordError = _isPasswordValid
            ? ''
            : 'Password must be at least 8 characters long, with uppercase, lowercase, number, and special character';
      });
    }
  }

  // Email validation logic
  void _validateEmail(String value) {
    if (value.isNotEmpty) {
      setState(() {
        _isEmailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-z]{2,4}$').hasMatch(value);
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final result = await AuthService().register(
          _fullNameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text.trim(),
          _role,
        );

        if (result['success']) {
          final token = result['token'];
          final user = result['user'];

          ref.read(userProvider.notifier).setUser(
            UserModel.fromJson(user),
            token,
            user['role'],
          );
          if (mounted) {
            context.pushReplacementNamed('mainNav', queryParameters: {'tab': '0'});
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Registration failed.")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => _validatePassword(_passwordCtrl.text));
    _emailCtrl.addListener(() => _validateEmail(_emailCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              const Text(
                'Create an account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign up to get started',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Full Name
              const Text(
                'Full Name',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedTextField(
                controller: _fullNameCtrl,
                hintText: 'Enter Your Full Name...',
                validator: (value) =>
                value == null || value.isEmpty ? 'Enter full name' : null,
                textStyle: const TextStyle(color: Colors.white),
                borderColor: Colors.grey,
                focusedBorderColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),

              // Email
              const Text(
                'Email',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedTextField(
                controller: _emailCtrl,
                hintText: 'yourname@gmail.com',
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter your email';
                  if (!_isEmailValid) return 'Please enter a valid Gmail address';
                  return null;
                },
                textStyle: const TextStyle(color: Colors.white),
                borderColor: Colors.grey,
                focusedBorderColor: Theme.of(context).primaryColor,
                errorBorderColor: Colors.red,
                isError: _emailCtrl.text.isNotEmpty && !_isEmailValid,
              ),
              const SizedBox(height: 16),

              // Password
              const Text(
                'Password',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedTextField(
                controller: _passwordCtrl,
                hintText: '•••••',
                obscureText: _isObscured,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter password';
                  if (!_isPasswordValid) return _passwordError;
                  return null;
                },
                textStyle: const TextStyle(color: Colors.white),
                borderColor: Colors.grey,
                focusedBorderColor: Theme.of(context).primaryColor,
                errorBorderColor: Colors.red,
                isError: _passwordCtrl.text.isNotEmpty && !_isPasswordValid,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
              if (_passwordCtrl.text.isNotEmpty && !_isPasswordValid)
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password must:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '• Be at least 8 characters long',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '• Contain an uppercase letter',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '• Contain a lowercase letter',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '• Contain a number',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '• Contain a special character',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Confirm Password
              const Text(
                'Confirm Password',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              OutlinedTextField(
                controller: _confirmCtrl,
                hintText: '•••••',
                obscureText: _isObscured,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Confirm password';
                  if (value != _passwordCtrl.text)
                    return 'Passwords do not match';
                  return null;
                },
                textStyle: const TextStyle(color: Colors.white),
                borderColor: Colors.grey,
                focusedBorderColor: Theme.of(context).primaryColor,
                errorBorderColor: Colors.red,
                isError: _confirmCtrl.text.isNotEmpty &&
                    _confirmCtrl.text != _passwordCtrl.text,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
              if (_confirmCtrl.text.isNotEmpty &&
                  _confirmCtrl.text != _passwordCtrl.text)
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Passwords do not match',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),

              // Role Selection
              const Text(
                'Register as',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Radio<String>(
                        value: 'listener',
                        groupValue: _role,
                        onChanged: (value) {
                          if (value != null) setState(() => _role = value);
                        },
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      const Text('Listener', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'artist',
                        groupValue: _role,
                        onChanged: (value) {
                          if (value != null) setState(() => _role = value);
                        },
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      const Text('Artist', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
              if (_role == 'artist')
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Artist accounts require approval from our team',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 32),

              CustomButton(
                text: _isLoading ? 'Registering...' : 'Create account',
                onPressed: _isLoading ||
                    !_isPasswordValid ||
                    !_isEmailValid ||
                    _fullNameCtrl.text.isEmpty ||
                    _emailCtrl.text.isEmpty ||
                    _passwordCtrl.text.isEmpty ||
                    _confirmCtrl.text.isEmpty ||
                    _passwordCtrl.text != _confirmCtrl.text
                    ? null
                    : _register,
              ),
              const SizedBox(height: 16),

              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  GestureDetector(
                    onTap: () => context.pushNamed('login'),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class OutlinedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final String? Function(String?) validator;
  final TextStyle textStyle;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color errorBorderColor;
  final bool isError;
  final Widget? suffixIcon;

  const OutlinedTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    required this.validator,
    required this.textStyle,
    this.borderColor = Colors.grey,
    this.focusedBorderColor = Colors.blue,
    this.errorBorderColor = Colors.red,
    this.isError = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: textStyle,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: textStyle.copyWith(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: focusedBorderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: errorBorderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: errorBorderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}