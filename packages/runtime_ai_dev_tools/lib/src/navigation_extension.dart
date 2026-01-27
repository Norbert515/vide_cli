import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';

/// Registers the navigation state service extension
///
/// This extension provides information about the current navigation state,
/// including the current route, route stack, and modal route count.
void registerNavigationExtension() {
  print(
      '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getNavigationState');

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getNavigationState',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getNavigationState extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final result = _getNavigationState();
        return developer.ServiceExtensionResponse.result(json.encode(result));
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] getNavigationState failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to get navigation state: $e\n$stackTrace',
        );
      }
    },
  );
}

/// Get the current navigation state from the widget tree
Map<String, dynamic> _getNavigationState() {
  print('🔍 [RuntimeAiDevTools] Getting navigation state');

  final binding = WidgetsBinding.instance;
  final rootElement = binding.rootElement;

  if (rootElement == null) {
    print('   ⚠️  No root element available');
    return {
      'status': 'error',
      'error': 'No root element available',
    };
  }

  // Find NavigatorState instances in the widget tree
  final navigatorStates = <NavigatorState>[];
  _findNavigatorStates(rootElement, navigatorStates);

  if (navigatorStates.isEmpty) {
    print('   ⚠️  No Navigator found in widget tree');
    return {
      'status': 'success',
      'currentRoute': null,
      'routeStack': <String>[],
      'canGoBack': false,
      'modalRoutes': 0,
    };
  }

  // Use the first (typically root) navigator for main navigation info
  final navigator = navigatorStates.first;

  // Extract route information
  final routeStack = <String>[];
  var modalRouteCount = 0;
  String? currentRoute;

  // Try to access routes via the overlay (Navigator uses an Overlay internally)
  // We'll traverse the navigator's context to find route information
  navigator.context.visitChildElements((element) {
    _extractRoutesFromElement(element, routeStack, (isModal) {
      if (isModal) modalRouteCount++;
    });
  });

  // Get the current route name from the topmost route
  if (routeStack.isNotEmpty) {
    currentRoute = routeStack.last;
  }

  // Check if we can go back (more than one route in stack)
  final canGoBack = navigator.canPop();

  print('   ✅ Navigation state extracted');
  print('   Current route: $currentRoute');
  print('   Route stack: $routeStack');
  print('   Can go back: $canGoBack');
  print('   Modal routes: $modalRouteCount');

  return {
    'status': 'success',
    'currentRoute': currentRoute,
    'routeStack': routeStack,
    'canGoBack': canGoBack,
    'modalRoutes': modalRouteCount,
  };
}

/// Recursively find NavigatorState instances in the element tree
void _findNavigatorStates(Element element, List<NavigatorState> states) {
  if (element is StatefulElement && element.state is NavigatorState) {
    states.add(element.state as NavigatorState);
  }
  element.visitChildren((child) => _findNavigatorStates(child, states));
}

/// Extract route information from overlay entries
void _extractRoutesFromElement(
  Element element,
  List<String> routeStack,
  void Function(bool isModal) onRouteFound,
) {
  // Check if this element is associated with a route
  final widget = element.widget;

  // Look for ModalRoute in the element's ancestors
  final modalRoute = ModalRoute.of(element);
  if (modalRoute != null) {
    final routeName = _getRouteName(modalRoute);
    if (!routeStack.contains(routeName)) {
      routeStack.add(routeName);
      onRouteFound(modalRoute is PopupRoute);
    }
  }

  // Also check for route-specific widgets that indicate navigation
  if (widget is Navigator) {
    // Found a nested navigator, get its routes
    final navigatorState = (element as StatefulElement).state as NavigatorState;
    _extractRoutesFromNavigator(navigatorState, routeStack, onRouteFound);
  }

  element.visitChildren((child) {
    _extractRoutesFromElement(child, routeStack, onRouteFound);
  });
}

/// Extract routes from a NavigatorState
void _extractRoutesFromNavigator(
  NavigatorState navigator,
  List<String> routeStack,
  void Function(bool isModal) onRouteFound,
) {
  // Use the navigator's overlay to access route entries
  final overlay = navigator.overlay;
  if (overlay == null) return;

  final overlayState = overlay;

  // The overlay contains OverlayEntry objects that correspond to routes
  // We need to check the widget tree under the overlay
  overlayState.context.visitChildElements((element) {
    final modalRoute = ModalRoute.of(element);
    if (modalRoute != null) {
      final routeName = _getRouteName(modalRoute);
      if (!routeStack.contains(routeName)) {
        routeStack.add(routeName);
        onRouteFound(modalRoute is PopupRoute);
      }
    }
  });
}

/// Get a displayable name for a route
String _getRouteName(Route<dynamic> route) {
  // Try to get the route name from settings
  final settings = route.settings;
  if (settings.name != null && settings.name!.isNotEmpty) {
    return settings.name!;
  }

  // Fall back to the route type name
  return route.runtimeType.toString();
}
