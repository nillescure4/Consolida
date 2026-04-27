import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Inici de sessió',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Correu electrònic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contrasenya',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Entrar'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Crear compte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}