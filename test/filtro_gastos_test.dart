import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:exploraec/controllers/auth_controller.dart';
import 'package:exploraec/controllers/gastos_controller.dart';
import 'package:exploraec/i18n/app_translations.dart';
import 'package:exploraec/screens/gastos_screen.dart';
import 'package:exploraec/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// Backend falso en memoria para la prueba del filtro de gastos.
class _BackendFalso implements HttpClientAdapter {
  static var _usuarios = 0;
  final idUsuario = ++_usuarios;
  final gastos = <Map<String, dynamic>>[];

  ResponseBody _json(Object? cuerpo, int codigo, [Map<String, List<String>> cabeceras = const {}]) =>
      ResponseBody.fromString(cuerpo == null ? '' : jsonEncode(cuerpo), codigo,
          headers: {Headers.contentTypeHeader: ['application/json'], ...cabeceras});

  @override
  Future<ResponseBody> fetch(RequestOptions opciones, Stream<Uint8List>? cuerpo, Future<void>? cancelar) async {
    final ruta = opciones.path;
    if (ruta == '/usuarios/token') {
      return _json({'access_token': 'tok-a@b.com', 'token_type': 'bearer'}, 200);
    }
    if (ruta == '/usuarios/me') {
      return _json({'id': idUsuario, 'email': 'a@b.com'}, 200);
    }
    if (ruta == '/gastos/categorias') {
      return _json({'categorias': ['comida', 'transporte', 'entretenimiento', 'otros'], 'limite_por_categoria': 500.0}, 200);
    }
    if (ruta == '/gastos/' && opciones.method == 'GET') {
      return _json(gastos, 200, {'x-total-count': ['${gastos.length}']});
    }
    return _json({'detail': 'Ruta no prevista: $ruta'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('hive_filtro').path));

  testWidgets('Al elegir comida, solo se ven los gastos de comida', (tester) async {
    final backend = _BackendFalso();
    backend.gastos.addAll([
      {
        'id': 1,
        'descripcion': 'Almuerzo tradicional',
        'monto': 8.5,
        'categoria': 'comida',
        'fecha': '2026-10-24',
      },
      {
        'id': 2,
        'descripcion': 'Taxi al mirador',
        'monto': 4.0,
        'categoria': 'transporte',
        'fecha': '2026-10-24',
      },
      {
        'id': 3,
        'descripcion': 'Cena típica',
        'monto': 12.0,
        'categoria': 'comida',
        'fecha': '2026-10-24',
      },
    ]);

    await tester.runAsync(() async {
      Get.reset();
      Get.testMode = true;
      FlutterSecureStorage.setMockInitialValues({});
      Get.put(ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://backend'))..httpClientAdapter = backend));
      final auth = Get.put(AuthController());
      await auth.iniciarSesion('a@b.com', 'clave-1234');
      final controller = Get.put(GastosController());
      for (var i = 0; i < 200 && controller.categorias.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      for (var i = 0; i < 200 && controller.estado.value.name != 'exito'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('es', 'EC'),
        home: const GastosScreen(),
      ),
    );
    await tester.pump();

    // Se muestran todos los gastos al inicio y los chips de opciones
    expect(find.text('Todas'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'comida'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'transporte'), findsOneWidget);

    expect(find.text('Almuerzo tradicional'), findsOneWidget);
    expect(find.text('Taxi al mirador'), findsOneWidget);
    expect(find.text('Cena típica'), findsOneWidget);

    // Al tocar comida, solo se ven los gastos de comida
    await tester.tap(find.widgetWithText(FilterChip, 'comida'));
    await tester.pump();

    expect(find.text('Almuerzo tradicional'), findsOneWidget);
    expect(find.text('Cena típica'), findsOneWidget);
    expect(find.text('Taxi al mirador'), findsNothing);

    // Al tocar Todas, se vuelven a ver todos los gastos
    await tester.tap(find.widgetWithText(FilterChip, 'Todas'));
    await tester.pump();

    expect(find.text('Almuerzo tradicional'), findsOneWidget);
    expect(find.text('Taxi al mirador'), findsOneWidget);
    expect(find.text('Cena típica'), findsOneWidget);
  });
}
