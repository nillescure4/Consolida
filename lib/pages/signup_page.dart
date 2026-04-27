import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Crear compte',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            const TextField(
              decoration: InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 16),

            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmar contrasenya',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                // 🔥 ELIMINA TOT L’HISTORIAL → NO BACK POSSIBLE
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Crear compte'),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () {
                // També sense historial
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Ja tinc compte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}