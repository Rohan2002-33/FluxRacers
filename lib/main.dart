import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for menu UI (will switch to landscape during racing)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
        runApp(const FluxRacersApp());
      });
}
