import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'role_selection_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creatingAccount = false;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 8) {
      _showError('Inserisci email e una password di almeno 8 caratteri.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_creatingAccount) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? 'Autenticazione non riuscita.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accesso sicuro')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _creatingAccount ? 'Crea account' : 'Accedi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _submitting ? null : _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_creatingAccount ? 'CREA ACCOUNT' : 'ACCEDI'),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _creatingAccount = !_creatingAccount),
                  child: Text(
                    _creatingAccount
                        ? 'Hai già un account? Accedi'
                        : 'Nuovo dispositivo? Crea account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
