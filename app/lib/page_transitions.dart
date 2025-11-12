import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// Crea una rotta con transizione Shared Axis (Orizzontale)
/// Ideale per la navigazione standard (Lista -> Dettaglio)
Route createSharedAxisRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal, // Movimento X
        child: child,
      );
    },
    // Durata leggermente più lunga dello standard per apprezzare l'effetto
    transitionDuration: const Duration(milliseconds: 400),
  );
}