import 'package:flutter/material.dart';

import 'home/home_screen.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Tower Defense',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,

      ),
      // themeMode: ThemeMode.dark,
      // home: const GameBoard(),
      home: const HomeScreen(),
      // home: const GameScreen(),
    );
  }
}