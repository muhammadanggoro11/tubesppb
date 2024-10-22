import 'package:flutter/material.dart';
import 'package:tickly/screens/home_screen.dart';
import 'package:tickly/screens/login.dart';
import 'package:tickly/screens/register.dart';

MaterialPageRoute _pageRoute(
        {required Widget body, required RouteSettings settings}) =>
    MaterialPageRoute(builder: (_) => body, settings: settings);
Route? generateRoute(RouteSettings settings) {
  Route? route;
  final args = settings.arguments;
  switch (settings.name) {
    case rLogin:
      route = _pageRoute(body: const LoginScreen(), settings: settings);
      break;
    case rRegister:
      route = _pageRoute(body: const RegisterScreen(), settings: settings);
      break;
    case rHome:
      route = _pageRoute(body: const HomeScreen(), settings: settings);
      break;
  }
  return route;
}

final NAV_KEY = GlobalKey<NavigatorState>();
const String rLogin = '/login';
const String rRegister = '/register';
const String rHome = '/home';
