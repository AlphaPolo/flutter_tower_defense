import 'dart:async';

import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';

import '../widget/dialog/dialog_utils.dart';


class AuthProvider with ChangeNotifier {
  User? user;
  StreamSubscription? userAuthSub;

  AuthProvider() {
    userAuthSub = FirebaseAuth.instance.authStateChanges().listen((newUser) {
      print('AuthProvider - FirebaseAuth - onAuthStateChanged - $newUser');
      user = newUser;
      notifyListeners();
    }, onError: (e) {
      print('AuthProvider - FirebaseAuth - onAuthStateChanged - $e');
    });
  }

  @override
  void dispose() {
    if (userAuthSub != null) {
      userAuthSub!.cancel();
      userAuthSub = null;
    }
    super.dispose();
  }

  bool get isAnonymous {
    assert(user != null);
    final isAnonymousUser = user?.providerData.none((info) =>
            info.providerId == "facebook.com" || info.providerId == "google.com" || info.providerId == "password") ??
        false;
    return isAnonymousUser;
  }

  bool get isAuthenticated {
    return user != null;
  }

  void signIn(BuildContext? context) {
    if(isAuthenticated) return;
    context?.let(showLoginDialog);
  }

  Future<bool?> signInAnonymous([BuildContext? context]) async {

    context?.let(showLoadingDialog);

    final inputName = await context?.let((context) => showInputDialog(
      context,
      title: '請輸入名稱',
      hint: 'please input name...',
    ));

    if(inputName == null) return null;
    final result = await FirebaseAuth.instance.signInAnonymously();
    await result.user?.updateDisplayName(inputName);
    await result.user?.reload();

    user = FirebaseAuth.instance.currentUser;
    notifyListeners();

    context?.let(Navigator.of).popUntil((route) {
      return route.settings.name != 'loading';
    });

    return user?.displayName == inputName;
  }

  void signOut() {
    if(!isAuthenticated) return;
    FirebaseAuth.instance.signOut();
  }

  void showLoginDialog(BuildContext context) {
    final providers = [EmailAuthProvider()];
    final screen = SignInScreen(
      providers: providers,
      actions: [
        AuthStateChangeAction<SignedIn>((context, state) {
          print(state);
          Navigator.pop(context);
          // alphacostankion@gmail.com
          // Navigator.pushReplacementNamed(context, '/profile');
        }),
      ],
      footerBuilder: (context, action) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: () async {
                await signInAnonymous(context);
                Navigator.maybeOf(context)?.pop(true);
              },
              child: Text('Anonymous Login'),
            ),
          ],
        );
      },
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => screen,
      ),
    );
  }


}
