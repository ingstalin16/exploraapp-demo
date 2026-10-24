import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/main.dart';
import 'package:exploraec/services/ai_assistant_service.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:exploraec/services/settings_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('hive_widget_test').path);
    await Hive.openBox<Map>('favoritos');
    await SettingsService.abrir();
  });

  testWidgets('ExploraEcApp inicia correctamente', (WidgetTester tester) async {
    Get.reset();
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://prueba'))), permanent: true);
    Get.put(AuthController(), permanent: true);
    Get.put(AiAssistantService(), permanent: true);

    await tester.pumpWidget(const ExploraEcApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(ExploraEcApp), findsOneWidget);
  });
}

