// lib/share/local/constants.dart
//
// The global `String? uID` has been removed and replaced by AuthService.
// Use AuthService.instance.currentUid instead.
//
// This file is kept for any remaining shared constants.

import 'package:flutter/material.dart';

/// Gold accent colour used throughout the app.
const kGold    = Color(0xFFe5c687);
const kGoldDim = Color(0xFFc7ab72);

/// Navigator key used by FCMService to push routes without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
