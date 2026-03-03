import 'package:flutter/cupertino.dart';
import 'dart:async';

import 'Screens/authwrapper.dart';
import 'SplashScreen.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(const Duration(seconds: 2), () { // ⏳ show for ~6 seconds
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const AuthWrapper()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MentorAISplashScreen();
  }
}

