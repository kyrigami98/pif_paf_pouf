import "package:flutter/material.dart";

//key for the navigator (go_router)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> rootShellNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

//key for the alert
final GlobalKey<ScaffoldMessengerState> alertKey = GlobalKey<ScaffoldMessengerState>();
