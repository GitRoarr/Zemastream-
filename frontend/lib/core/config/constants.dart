import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String localNetworkIP = '10.6.153.233';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'http://$localNetworkIP:3000';
    } else {
      return 'http://localhost:3000';
    }
  }
}

final String baseUrl = AppConstants.baseUrl;
