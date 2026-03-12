import 'package:flutter/material.dart';

enum RouteAnimationType {
  slideAndFade,
  scale,
  rotation,
}

class CustomPageRoute<T> extends PageRouteBuilder<T> {  // Added generic type parameter
  final Widget child;
  final AxisDirection direction;
  final RouteAnimationType animationType;

  CustomPageRoute({
    required this.child,
    this.direction = AxisDirection.right,
    this.animationType = RouteAnimationType.slideAndFade,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => child,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (animationType) {
      case RouteAnimationType.slideAndFade:
        return SlideTransition(
          position: Tween<Offset>(
            begin: _getBeginOffset(),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      case RouteAnimationType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        );
      case RouteAnimationType.rotation:
        return RotationTransition(
          turns: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
    }
  }

  Offset _getBeginOffset() {
    switch (direction) {
      case AxisDirection.up:
        return const Offset(0, 1);
      case AxisDirection.down:
        return const Offset(0, -1);
      case AxisDirection.left:
        return const Offset(1, 0);
      case AxisDirection.right:
        return const Offset(-1, 0);
    }
  }
}

class RouteAnimations {
  static Route<T> createRoute<T>(
    Widget page, {
    AxisDirection direction = AxisDirection.right,
    RouteAnimationType animationType = RouteAnimationType.slideAndFade,
  }) {
    return CustomPageRoute<T>(
      child: page,
      direction: direction,
      animationType: animationType,
    );
  }

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    AxisDirection direction = AxisDirection.right,
    RouteAnimationType animationType = RouteAnimationType.slideAndFade,
  }) {
    return Navigator.push<T>(
      context,
      createRoute<T>(
        page,
        direction: direction,
        animationType: animationType,
      ),
    );
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    AxisDirection direction = AxisDirection.right,
    RouteAnimationType animationType = RouteAnimationType.slideAndFade,
    TO? result,
  }) {
    return Navigator.pushReplacement<T, TO>(
      context,
      createRoute<T>(
        page,
        direction: direction,
        animationType: animationType,
      ),
      result: result,
    );
  }

  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Widget page, {
    AxisDirection direction = AxisDirection.right,
    RouteAnimationType animationType = RouteAnimationType.slideAndFade,
    bool Function(Route<dynamic>)? predicate,
  }) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      createRoute<T>(
        page,
        direction: direction,
        animationType: animationType,
      ),
      (Route<dynamic> route) => predicate?.call(route) ?? false,
    );
  }
}