import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marga_app/screens/bitacora/bitacora_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:typed_data';

class AdultoMayorScreen extends StatefulWidget {
  const AdultoMayorScreen({super.key});

  @override
  _AdultoMayorScreenState createState() => _AdultoMayorScreenState();
}

class _AdultoMayorScreenState extends State<AdultoMayorScreen> {
  final TextEditingController _codigoController = TextEditingController();
  
  bool _estaVinculado = false;
  int? _adultoMayorId;
  String _nombreAdulto = "";
  
  bool _isLoading = false;
  List<dynamic> _misMedicamentos = [];

  final String _baseUri = "http://192.168.1.155/derek_solutions_api/";

  // Instancia local de notificaciones
  final FlutterLocalNotificationsPlugin _notificacionesPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _inicializarNotificaciones();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSesionLocal();
    });
  }

  // Inicializa el plugin de alertas y pide permisos
  Future<void> _inicializarNotificaciones() async {
    // Inicializar timezone
    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificacionesPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permisos en Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificacionesPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // Manejar cuando el usuario toca una notificación
  void _onNotificationTap(NotificationResponse response) {
    print("🔔 Notificación tocada: ${response.payload}");
    // Aquí puedes navegar a la pantalla de medicamentos o abrir la app
  }

  Future<void> _verificarSesionLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? idGuardado = prefs.getInt('adulto_mayor_id');
      final String? nombreGuardado = prefs.getString('adulto_mayor_nombre');

      if (idGuardado != null && nombreGuardado != null) {
        setState(() {
          _adultoMayorId = idGuardado;
          _nombreAdulto = nombreGuardado;
          _estaVinculado = true;
        });
        _obtenerMisMedicamentos(); 
      }
    } catch (e) {
      print("Aviso: SharedPreferences no inicializado aún: $e");
    }
  }

  Future<void> _guardarSesionLocal(int id, String nombre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('adulto_mayor_id', id);
      await prefs.setString('adulto_mayor_nombre', nombre);
    } catch (e) {
      print("Error al escribir en disco local: $e");
    }
  }

  Future<void> _vincularDispositivo() async {
    if (_codigoController.text.trim().length != 6) {
      _msg("El código debe tener 6 dígitos", Colors.orange);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final response = await http.post(
        Uri.parse("${_baseUri}vincular_codigo.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"codigo_vinculacion": _codigoController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final int idObtenido = int.parse(data['adulto_mayor_id'].toString());
        final String nombreObtenido = data['nombre'].toString();

        await _guardarSesionLocal(idObtenido, nombreObtenido);

        setState(() {
          _adultoMayorId = idObtenido;
          _nombreAdulto = nombreObtenido;
          _estaVinculado = true;
          _isLoading = false;
        });

        _msg("¡Enlace Exitoso!", Colors.green);
        _obtenerMisMedicamentos();
      } else {
        setState(() { _isLoading = false; });
        _msg(data['message'] ?? "Código inválido", Colors.red);
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _msg("Error de conexión al servidor", Colors.red);
    }
  }

  Future<void> _obtenerMisMedicamentos() async {
    if (_adultoMayorId == null) {
      print("⚠️ ALERTA: El ID del adulto mayor es NULL en Flutter.");
      return;
    }
    setState(() { _isLoading = true; });
    
    try {
      final url = "${_baseUri}obtener_medicamentos_adulto.php?adulto_mayor_id=$_adultoMayorId";
      print("📡 Conectando a: $url");

      final response = await http.get(Uri.parse(url));
      print("📥 Código de respuesta del servidor: ${response.statusCode}");
      print("📥 Respuesta: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<dynamic> nuevosMedicamentos = data['medicamentos'] ?? [];
          
          print("📊 Medicamentos recibidos: ${nuevosMedicamentos.length}");
          
          // Procesar notificaciones y novedades
          await _procesarAlertasLocalesyNovedades(nuevosMedicamentos);

          setState(() { 
            _misMedicamentos = nuevosMedicamentos; 
          });
        } else {
          print("❌ El servidor respondió success: false. Mensaje: ${data['message']}");
        }
      }
    } catch (e) {
      print("❌ Error de red u obtención: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Compara la lista previa con la nueva para alertar novedades y recalcular alarmas
  Future<void> _procesarAlertasLocalesyNovedades(List<dynamic> nuevaLista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtenemos los IDs previamente guardados
      List<String>? idsPrevios = prefs.getStringList('medicamentos_ids_vistos');
      
      // Mapeamos los IDs de la nueva lista
      List<String> idsNuevos = nuevaLista
          .where((m) => m['id'] != null)
          .map((m) => m['id'].toString())
          .toList();
      
      // Si ya teníamos una lista guardada, buscamos medicamentos nuevos
      if (idsPrevios != null && idsPrevios.isNotEmpty) {
        List<String> agregados = idsNuevos.where((id) => !idsPrevios.contains(id)).toList();

        if (agregados.isNotEmpty) {
          for (var idNuevo in agregados) {
            var medNuevo = nuevaLista.firstWhere(
              (m) => m['id'].toString() == idNuevo, 
              orElse: () => null
            );
            if (medNuevo != null) {
              await _dispararNotificacionInmediata(
                "¡Nuevo medicamento asignado! 💊",
                "Tu familiar te agregó: ${medNuevo['nombre']} (${medNuevo['dosis']})",
                "medicamento_nuevo"
              );
            }
          }
        }
      }

      // Guardamos la lista actual de IDs para la siguiente comparación
      await prefs.setStringList('medicamentos_ids_vistos', idsNuevos);

      // Reprogramamos las alarmas horarias
      await _sincronizarAlarmasHorarias(nuevaLista);

    } catch (e) {
      print("Aviso en segundo plano (las alertas no impiden mostrar la lista): $e");
    }
  }

  // Lanza una notificación nativa inmediata en el dispositivo
  Future<void> _dispararNotificacionInmediata(String titulo, String cuerpo, String payload) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_adulto_novedades',
      'Novedades de Medicamentos',
      channelDescription: 'Avisa cuando el familiar agrega o modifica tratamientos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    int idNotif = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notificacionesPlugin.show(
      idNotif, 
      titulo, 
      cuerpo, 
      platformDetails,
      payload: payload,
    );
  }

  // Configura las alertas locales de anticipación, exactas y atrasadas
  Future<void> _sincronizarAlarmasHorarias(List<dynamic> medicamentos) async {
    // Limpiamos alertas previas del adulto mayor para evitar duplicados
    await _notificacionesPlugin.cancelAll();

    // Filtrar solo medicamentos pendientes o en espera
    List<dynamic> medicamentosPendientes = medicamentos.where((med) {
      String estado = med['estado'] ?? 'pendiente';
      return estado != 'tomado';
    }).toList();

    if (medicamentosPendientes.isEmpty) {
      print('📭 No hay medicamentos pendientes para programar notificaciones');
      return;
    }

    print('📊 Programando notificaciones para ${medicamentosPendientes.length} medicamentos');

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_alertas_toma',
      'Recordatorios de Toma',
      channelDescription: 'Alarmas para la administración de medicinas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    );
    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final ahora = tz.TZDateTime.now(tz.local);

    // Agrupar medicamentos por horario para no duplicar notificaciones
    Map<String, List<dynamic>> medicamentosPorHorario = {};
    
    for (var med in medicamentosPendientes) {
      String horario = med['horario'] ?? '08:00:00';
      if (!medicamentosPorHorario.containsKey(horario)) {
        medicamentosPorHorario[horario] = [];
      }
      medicamentosPorHorario[horario]!.add(med);
    }

    print('📊 Horarios únicos: ${medicamentosPorHorario.keys.length}');

    // Programar notificaciones por cada horario único
    for (var entry in medicamentosPorHorario.entries) {
      String horaStr = entry.key;
      List<dynamic> medsEnHorario = entry.value;
      
      try {
        List<String> partes = horaStr.split(':');
        int hora = int.parse(partes[0]);
        int minuto = int.parse(partes[1]);

        // Calcular la fecha y hora de la toma de hoy
        var tiempoBase = tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day, hora, minuto);

        // Si ya pasó la hora de hoy, programamos para mañana
        if (tiempoBase.isBefore(ahora)) {
          tiempoBase = tiempoBase.add(const Duration(days: 1));
        }

        // Construir mensaje con todos los medicamentos de ese horario
        String listaMedicamentos = medsEnHorario.map((m) => 
          "${m['nombre']} (${m['dosis']})"
        ).join(', ');

        int medicamentoId = medsEnHorario.first['id'] ?? 0;

        // --- ALERTA 1: "Ya casi te toca" (10 Minutos Antes) ---
        var tiempoAntes = tiempoBase.subtract(const Duration(minutes: 10));
        if (tiempoAntes.isAfter(ahora)) {
          await _notificacionesPlugin.zonedSchedule(
            medicamentoId + 100000, 
            "⏰ ¡Prepara tus medicamentos!",
            "En 10 minutos te toca: $listaMedicamentos",
            tiempoAntes,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: "recordatorio_10min",
          );
          print('✅ 10 min antes programada para: ${tiempoAntes.toString()}');
        }

        // --- ALERTA 2: "Hora de tomar" (Hora Exacta) ---
        await _notificacionesPlugin.zonedSchedule(
          medicamentoId + 200000, 
          "💊 ¡Hora de tus medicamentos!",
          "Toma: $listaMedicamentos. Abre la app y confirma.",
          tiempoBase,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "recordatorio_hora",
        );
        print('✅ Hora exacta programada para: ${tiempoBase.toString()}');

        // --- ALERTA 3: "Se te pasó la hora" (15 Minutos Después) ---
        var tiempoDespues = tiempoBase.add(const Duration(minutes: 15));
        await _notificacionesPlugin.zonedSchedule(
          medicamentoId + 300000, 
          "⚠️ ¡No olvides tus medicamentos!",
          "Ya pasaron 15 minutos. Toma: $listaMedicamentos",
          tiempoDespues,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "recordatorio_retraso",
        );
        print('✅ 15 min después programada para: ${tiempoDespues.toString()}');

        // --- ALERTA 4: Recordatorio adicional (30 Minutos Después) ---
        var tiempo30Min = tiempoBase.add(const Duration(minutes: 30));
        await _notificacionesPlugin.zonedSchedule(
          medicamentoId + 400000, 
          "🔔 Último recordatorio",
          "Ya pasó media hora. ¿Ya tomaste: $listaMedicamentos?",
          tiempo30Min,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "recordatorio_30min",
        );
        print('✅ 30 min después programada para: ${tiempo30Min.toString()}');

        print("✅ Notificaciones programadas para: $horaStr - $listaMedicamentos");

      } catch (e) {
        print("❌ Error programando tiempos para horario $horaStr: $e");
      }
    }

    // Mostrar resumen de notificaciones programadas
    _mostrarResumenNotificaciones(medicamentosPorHorario.keys.length);
  }

  // Mostrar un resumen de las notificaciones programadas
  void _mostrarResumenNotificaciones(int totalHorarios) {
    print("📊 Total de horarios con notificaciones: $totalHorarios");
    if (totalHorarios > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🔔 $totalHorarios recordatorios programados"),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue[700],
        ),
      );
    }
  }

  // CONFIRMAR TOMA ("YA LO TOMÉ")
  Future<void> _confirmarTomaMedicamento(int medicamentoId, String nombreMed) async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.post(
        Uri.parse("${_baseUri}registrar_toma.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "adulto_mayor_id": _adultoMayorId,
          "medicamento_id": medicamentoId
        }),
      );

      final data = jsonDecode(response.body);
      print("📥 Respuesta registrar_toma: ${response.body}");
      
      setState(() { _isLoading = false; });

      if (response.statusCode == 200 && data['success'] == true) {
        // Cancelamos alertas de retraso para este medicamento
        await _notificacionesPlugin.cancel(medicamentoId + 300000);
        await _notificacionesPlugin.cancel(medicamentoId + 400000);

        bool esRecurrente = data['recurrente'] ?? false;
        String? siguienteHora = data['siguiente_horario'];

        // Disparar notificación de confirmación
        await _dispararNotificacionInmediata(
          "✅ ¡Bien hecho!",
          "Has tomado $nombreMed correctamente.",
          "confirmacion_toma"
        );

        // Mostrar el diálogo de felicitación
        _mostrarDialogoFelicitacion(nombreMed, esRecurrente, siguienteHora);

        // Esperar un momento y refrescar la lista
        await Future.delayed(const Duration(seconds: 1));
        await _obtenerMisMedicamentos(); 
      } else {
        _msg(data['message'] ?? "No se pudo registrar", Colors.red);
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _msg("Error de red al registrar toma: $e", Colors.red);
      print("❌ Error en confirmarToma: $e");
    }
  }

  // Interfaz visual para felicitar y motivar al adulto mayor
  void _mostrarDialogoFelicitacion(String medicamento, bool esRecurrente, String? siguienteHora) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "¡Excelente trabajo! 🎉", 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 80, color: Colors.amber),
              const SizedBox(height: 15),
              Text(
                "Te has tomado tu medicamento:\n\"$medicamento\"",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),
              if (esRecurrente && siguienteHora != null) ...[
                const Text(
                  "Este medicamento es recurrente.",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 5),
                Text(
                  "Tu siguiente toma será a las:\n$siguienteHora hrs",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                ),
                const SizedBox(height: 10),
                Text(
                  "🔔 Recibirás un recordatorio cuando sea hora",
                  style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                ),
              ] else ...[
                const Text(
                  "¡Toma única completada!\nEste medicamento ha desaparecido de tu lista por hoy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Entendido 👍", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  // MENÚ DE AUXILIO (SOS)
  void _mostrarMenuSOS() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.red[50],
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("🚨 MENÚ DE AUXILIO 🚨", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 10),
              const Text("Presiona el botón de lo que necesites en este momento:", style: TextStyle(fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 24),
              
              _buildBotonLlamada(
                label: "LLAMAR AL 911",
                color: Colors.red[700]!,
                icon: Icons.local_police,
                onTap: () => _ejecutarLlamada("tel:911"),
              ),
              const SizedBox(height: 16),
              
              _buildBotonLlamada(
                label: "LLAMAR A MI FAMILIAR",
                color: Colors.blue[800]!,
                icon: Icons.family_restroom,
                onTap: () => _obtenerTelefonoFamiliarYLLamar(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _ejecutarLlamada(String urlFormat) async {
    final Uri url = Uri.parse(urlFormat);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _msg("No se pudo iniciar la llamada telefónica", Colors.red);
    }
  }

  Future<void> _obtenerTelefonoFamiliarYLLamar() async {
    try {
      final response = await http.get(Uri.parse("${_baseUri}obtener_contacto_familiar.php?adulto_mayor_id=$_adultoMayorId"));
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['telefono'] != null) {
        _ejecutarLlamada("tel:${data['telefono']}");
      } else {
        _msg("Tu familiar no ha registrado un teléfono de contacto.", Colors.orange);
      }
    } catch (e) {
      _msg("Error al conectar con el servicio de emergencia", Colors.red);
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _notificacionesPlugin.cancelAll(); // Quitar alarmas al cerrar sesión
    } catch (e) {
      print("Error al limpiar preferencias: $e");
    }
    setState(() {
      _estaVinculado = false;
      _adultoMayorId = null;
      _misMedicamentos = [];
      _codigoController.clear();
    });
    
    _msg("Sesión cerrada correctamente", Colors.blue);
  }

  void _msg(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        title: Text(_estaVinculado ? "Mis Medicamentos" : "Configuración"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: _estaVinculado ? [
          IconButton(
            icon: const Icon(Icons.assessment_outlined, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BitacoraScreen(adultoMayorId: _adultoMayorId!),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.sync, size: 32), onPressed: _obtenerMisMedicamentos),
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion)
        ] : null,
      ),
      floatingActionButton: _estaVinculado ? FloatingActionButton.extended(
        onPressed: _mostrarMenuSOS,
        backgroundColor: Colors.red[700],
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
        label: const Text("¡AYUDA!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: _estaVinculado ? _buildListaMedicamentos() : _buildFormularioCodigo(),
          ),
    );
  }

  Widget _buildListaMedicamentos() {
    // Verificar si hay medicamentos pendientes

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hola, $_nombreAdulto 👋", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900])),
        const Text("Medicamentos que debes tomar hoy:", style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500)),
        const SizedBox(height: 15),
        Expanded(
          child: _misMedicamentos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 90, color: Colors.green[600]),
                      const SizedBox(height: 12),
                      const Text("¡Muy bien!\nNo tienes medicinas pendientes.", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text("🔔 Los recordatorios están activos", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), 
                  itemCount: _misMedicamentos.length,
                  itemBuilder: (context, index) {
                    final med = _misMedicamentos[index];
                    String estado = med['estado'] ?? 'pendiente';
                    bool estaPendiente = estado != 'tomado';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 5,
                      color: estaPendiente ? Colors.blue[50] : Colors.green[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), 
                        side: BorderSide(
                          color: estaPendiente ? Colors.blue[300]! : Colors.green[300]!,
                          width: 2
                        )
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26, 
                                  backgroundColor: estaPendiente ? Colors.blue[900] : Colors.green[700],
                                  child: Icon(
                                    estaPendiente ? Icons.alarm : Icons.check_circle,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med['nombre'] ?? "Sin nombre", 
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: estaPendiente ? Colors.black87 : Colors.green[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Dosis: ${med['dosis'] ?? 'N/A'}", 
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: estaPendiente ? Colors.black54 : Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (!estaPendiente) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "✅ Tomado",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      if (estado == 'esperando') ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "⏳ Esperando siguiente toma",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: estaPendiente ? Colors.blue[900] : Colors.green[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    med['horario'] ?? "00:00", 
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (estaPendiente) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        int medId = int.parse(med['id'].toString());
                                        _confirmarTomaMedicamento(medId, med['nombre']);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 3,
                                      ),
                                      icon: const Icon(Icons.check, size: 28),
                                      label: const Text(
                                        "YA LO TOMÉ",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active,
                                      color: Colors.orange,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "🔔 Recibirás recordatorios 10 min antes, a la hora y 15 min después",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBotonLlamada({required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(16), 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioCodigo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_person_outlined, size: 80, color: Colors.blue),
        const SizedBox(height: 20),
        const Text("¡Bienvenido a tu Recordatorio!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text("Ingresa el código de 6 números que generó tu familiar.", style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        TextField(
          controller: _codigoController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6),
          decoration: const InputDecoration(
            counterText: "", 
            hintText: "000000", 
            border: OutlineInputBorder(), 
            fillColor: Colors.white, 
            filled: true
          ),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: _isLoading ? null : _vincularDispositivo,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16), 
            backgroundColor: Colors.blue[800], 
            foregroundColor: Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: const Text("Conectar con mi Familiar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}