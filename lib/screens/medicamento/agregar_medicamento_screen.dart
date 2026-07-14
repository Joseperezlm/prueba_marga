import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AgregarMedicamentoScreen extends StatefulWidget {
  final int familiarId;
  final Map<String, dynamic>? medicamento; 

  const AgregarMedicamentoScreen({
    Key? key, 
    required this.familiarId, 
    this.medicamento, 
  }) : super(key: key);

  @override
  _AgregarMedicamentoScreenState createState() => _AgregarMedicamentoScreenState();
}

class _AgregarMedicamentoScreenState extends State<AgregarMedicamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreMedController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  
  int? _adultoMayorSeleccionadoId;
  List<dynamic> _listaAdultosVinculados = [];
  bool _isLoadingAdultos = true;
  bool _isSaving = false;
  bool _isEditing = false; 

  TimeOfDay _horaSeleccionada = const TimeOfDay(hour: 8, minute: 0);
  int _recurrenciaHoras = 8;

  final String _baseUri = "http://192.168.1.155/derek_solutions_api/";
  
  // Instancia local de notificaciones
  final FlutterLocalNotificationsPlugin _notificacionesPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _inicializarNotificaciones();

    if (widget.medicamento != null) {
      _isEditing = true;
      _nombreMedController.text = widget.medicamento!['nombre'] ?? "";
      _dosisController.text = widget.medicamento!['dosis'] ?? "";
      
      try {
        String horaStr = widget.medicamento!['horario'] ?? "08:00:00";
        List<String> partes = horaStr.split(':');
        _horaSeleccionada = TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
      } catch (e) {
        print("Error al parsear la hora: $e");
      }

      if (widget.medicamento!['recurrencia_horas'] != null) {
        _recurrenciaHoras = int.parse(widget.medicamento!['recurrencia_horas'].toString());
      }
    }
    
    _cargarAdultosVinculados();
  }

  // Solicita permisos de notificación en Android 13 o superior
  Future<void> _inicializarNotificaciones() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificacionesPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // Programa las alertas locales recurrentes de forma nativa
  Future<void> _programarNotificacionesMedicamento({
    required int id,
    required String nombreMedicamento,
    required String dosis,
    required TimeOfDay horaInicio,
    required int frecuenciaHoras,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_medicamentos_id',
      'Recordatorios de Medicamentos',
      channelDescription: 'Canal usado para avisar la toma de medicamentos programados',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final ahora = tz.TZDateTime.now(tz.local);
    var programada = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      horaInicio.hour,
      horaInicio.minute,
    );

    if (programada.isBefore(ahora)) {
      if (frecuenciaHoras > 0) {
        while (programada.isBefore(ahora)) {
          programada = programada.add(Duration(hours: frecuenciaHoras));
        }
      } else {
        programada = programada.add(const Duration(days: 1));
      }
    }

    // 1. Notificación inmediata de confirmación
    await _notificacionesPlugin.show(
      id,
      '¡Medicamento Programado!',
      'Se ha agendado "$nombreMedicamento" ($dosis). Próxima toma: ${programada.hour.toString().padLeft(2, '0')}:${programada.minute.toString().padLeft(2, '0')}',
      platformDetails,
    );

    // 2. Agendar las alertas futuras
    int iteraciones = frecuenciaHoras > 0 ? 5 : 1; 
    for (int i = 0; i < iteraciones; i++) {
      final tz.TZDateTime tiempoToma = programada.add(Duration(hours: frecuenciaHoras * i));
      final int idNotificacionUnica = id + (i * 10000);

      await _notificacionesPlugin.zonedSchedule(
        idNotificacionUnica,
        'Hora de tu medicamento 💊',
        'Toca administrar: $nombreMedicamento ($dosis)',
        tiempoToma,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _cargarAdultosVinculados() async {
    setState(() { _isLoadingAdultos = true; });
    try {
      final response = await http.get(
        Uri.parse("${_baseUri}obtener_vinculados.php?familiar_id=${widget.familiarId}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _listaAdultosVinculados = data['adultos'] ?? [];
            
            if (_isEditing) {
              if (widget.medicamento!['adulto_mayor_id'] != null) {
                _adultoMayorSeleccionadoId = int.parse(widget.medicamento!['adulto_mayor_id'].toString());
              } else {
                final coincidencia = _listaAdultosVinculados.firstWhere(
                  (a) => a['nombre'].toString().toLowerCase() == widget.medicamento!['paciente'].toString().toLowerCase(),
                  orElse: () => null,
                );
                if (coincidencia != null) {
                  _adultoMayorSeleccionadoId = int.parse(coincidencia['id'].toString());
                }
              }
            }
            _isLoadingAdultos = false;
          });
          return;
        }
      }
    } catch (e) {
      print("Error al cargar vinculados: $e");
    }
    setState(() { _isLoadingAdultos = false; });
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada,
    );
    if (picked != null) {
      setState(() { _horaSeleccionada = picked; });
    }
  }

  Future<void> _guardarMedicamento() async {
    if (!_formKey.currentState!.validate()) return;
    if (_adultoMayorSeleccionadoId == null) {
      _showSnackbar("Por favor, selecciona a un Adulto Mayor", Colors.orange);
      return;
    }

    setState(() { _isSaving = true; });

    final String horaFormateada = "${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}:00";
    final String scriptDestino = _isEditing ? "editar_medicamento.php" : "guardar_medicamento.php";

    try {
      final Map<String, dynamic> bodyData = {
        "adulto_mayor_id": _adultoMayorSeleccionadoId,
        "nombre": _nombreMedController.text.trim(),
        "dosis": _dosisController.text.trim(),
        "horario": horaFormateada,
        "recurrencia_horas": _recurrenciaHoras,
      };

      if (_isEditing) {
        bodyData["id"] = widget.medicamento!['id'];
      }

      final response = await http.post(
        Uri.parse("$_baseUri$scriptDestino"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          
          // CORRECCIÓN PROTECTORA: Evitamos excepciones de casteo usando .toString() antes del parseo
          int medicamentoId = 0;
          if (_isEditing) {
            medicamentoId = int.tryParse(widget.medicamento!['id'].toString()) ?? 0;
          } else {
            medicamentoId = int.tryParse(data['medicamento_id'].toString()) ?? 0;
          }

          // Programar las alertas locales
          await _programarNotificacionesMedicamento(
            id: medicamentoId,
            nombreMedicamento: _nombreMedController.text.trim(),
            dosis: _dosisController.text.trim(),
            horaInicio: _horaSeleccionada,
            frecuenciaHoras: _recurrenciaHoras,
          );

          _showSnackbar(
            _isEditing ? "¡Medicamento e historial de alertas actualizados!" : "¡Medicamento y alertas sincronizados!", 
            Colors.green
          );
          
          Navigator.pop(context, true); 
        } else {
          _showSnackbar(data['message'] ?? "Error al procesar", Colors.redAccent);
        }
      } else {
        _showSnackbar("Error en el servidor: ${response.statusCode}", Colors.redAccent);
      }
    } catch (e) {
      print("🚨 Error capturado en Flutter: $e");
      _showSnackbar("Fallo al actualizar las alertas locales", Colors.redAccent);
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final bool elIdExisteEnLaLista = _listaAdultosVinculados.any((a) => int.parse(a['id'].toString()) == _adultoMayorSeleccionadoId);
    final int? valorDropdownSeguro = elIdExisteEnLaLista ? _adultoMayorSeleccionadoId : null;

    final List<int> horasPermitidas = [0, 4, 6, 8, 12, 24];
    final int valorRecurrenciaSeguro = horasPermitidas.contains(_recurrenciaHoras) ? _recurrenciaHoras : 8;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Medicamento" : "Programar Medicamento"), 
        backgroundColor: Colors.blue[700], 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: _cargarAdultosVinculados,
            tooltip: "Actualizar lista de abuelitos",
          )
        ],
      ),
      body: _isLoadingAdultos
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      value: valorDropdownSeguro, 
                      decoration: const InputDecoration(
                        labelText: "Asignar al Adulto Mayor",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                      hint: const Text("Selecciona un abuelito enlazado"),
                      items: _listaAdultosVinculados.map<DropdownMenuItem<int>>((dynamic adulto) {
                        return DropdownMenuItem<int>(
                          value: int.parse(adulto['id'].toString()),
                          child: Text(adulto['nombre'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() { _adultoMayorSeleccionadoId = val; });
                      },
                      validator: (value) => value == null ? "Este campo es requerido" : null,
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _nombreMedController,
                      decoration: const InputDecoration(labelText: "Nombre del Medicamento", border: OutlineInputBorder(), prefixIcon: Icon(Icons.medication)),
                      validator: (v) => v!.isEmpty ? "Ingresa el nombre del medicamento" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _dosisController,
                      decoration: const InputDecoration(labelText: "Dosis (Ej: 1 tableta, 5ml)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.shutter_speed)),
                      validator: (v) => v!.isEmpty ? "Ingresa la dosis requerida" : null,
                    ),
                    const SizedBox(height: 20),
                    
                    ListTile(
                      title: Text("Hora de toma: ${_horaSeleccionada.format(context)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.access_time, color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[400]!)),
                      onTap: () => _seleccionarHora(context),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<int>(
                      value: valorRecurrenciaSeguro, 
                      decoration: const InputDecoration(labelText: "Frecuencia de repetición", border: OutlineInputBorder(), prefixIcon: Icon(Icons.repeat)),
                      items: horasPermitidas.map((int value) {
                        return DropdownMenuItem<int>(
                          value: value, 
                          child: Text(value == 0 ? "Una sola toma (Sin repetición)" : "Cada $value horas"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() { _recurrenciaHoras = val!; }),
                    ),
                    const SizedBox(height: 35),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _guardarMedicamento,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        backgroundColor: _isEditing ? Colors.orange[800] : Colors.green[700], 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: _isSaving 
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_isEditing ? "Actualizar Cambios" : "Guardar y Sincronizar", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}