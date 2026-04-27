import 'package:flutter/material.dart';

class NavButton extends StatelessWidget {
  final String text;
  final String route;

  const NavButton({
    super.key,
    required this.text,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(text),
        ),
      ),
    );
  }
}