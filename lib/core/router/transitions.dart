import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A page that slides in a little from the right while fading, and fades out
/// again on the way back.
Page<void> reindeerPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final behind = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.85).animate(behind),
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
