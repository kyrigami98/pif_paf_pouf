import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/app/app.dart' show PifPafPoufMain;
import 'package:pif_paf_pouf/firebase_options.dart';

Future<void> init() async {
  //init flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  //firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //error widget style
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(color: Colors.white, child: const Center());
  };
}

void main() {
  init();
  runApp(const PifPafPoufMain());
}
