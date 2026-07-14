import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:marga_app/screens/login/login_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  // 1. Inicialización obligatoria antes de correr la app
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializar zonas horarias para las notificaciones
  tz.initializeTimeZones();
  
  try {
    // Asigna directamente la zona horaria de tu región (Ej: México / Centroamérica)
    // Esto evita depender de librerías nativas externas
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
  } catch (e) {
    print("Error al configurar la ubicación de la zona horaria: $e");
  }
  
  // 3. Configurar notificaciones
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}// Prueba de Git