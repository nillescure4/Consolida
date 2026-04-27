import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final FloatingActionButton? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: SafeArea(child: child),
      floatingActionButton: floatingActionButton,
    );
  }
}