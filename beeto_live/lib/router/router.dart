import 'package:flutter/widgets.dart';
// import 'package:beeto_live/module/audience/audience_page.dart';
// import 'package:beeto_live/module/connect/connect_page.dart';
// import 'package:beeto_live/module/host/host_page.dart';
import 'package:beeto_live/module/home/home_page.dart';
import 'package:beeto_live/module/home/test_page.dart';

class RouterManager {
  static initRouters() {
    _routes = {
      HOME: (context) => HomePage(),
      TEST: (context) => TestPage(),
      // HOST: (context) => HostPage(),
      // CONNECT: (context) => ConnectPage(),
      // AUDIENCE: (context) => AudiencePage(),
    };
    return _routes;
  }

  static const String HOME = '/home';
  static const String TEST = '/test';
  static const String HOST = '/host';
  static const String CONNECT = '/connect';
  static const String AUDIENCE = '/audience';

  static late Map<String, WidgetBuilder> _routes;
}
