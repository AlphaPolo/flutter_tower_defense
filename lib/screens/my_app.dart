import 'package:flutter/material.dart';

import 'home/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // home: const GameBoard(),
      home: const HomeScreen(),
      // home: const GameScreen(),
    );
  }
}