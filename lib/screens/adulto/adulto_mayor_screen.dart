import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Asegúrate de agregar este plugin en pubspec.yaml

class AdultoMayorScreen extends StatefulWidget {
  const AdultoMayorScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSesionLocal();
    });
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
    if (_adultoMayorId == null) return;
    setState(() { _isLoading = true; });
    
    try {
      final response = await http.get(Uri.parse("${_baseUri}obtener_medicamentos_adulto.php?adulto_mayor_id=$_adultoMayorId"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() { _misMedicamentos = data['medicamentos']; });
        }
      }
    } catch (e) {
      print("Error obteniendo la lista médica: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // HISTORIA DE USUARIO: CONFIRMAR TOMA ("YA LO TOMÉ")
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
      if (data['success'] == true) {
        _msg("¡Perfecto! Registramos tu toma de $nombreMed", Colors.green);
        _obtenerMisMedicamentos(); // Refrescar lista
      } else {
        _msg(data['message'] ?? "No se pudo registrar", Colors.red);
      }
    } catch (e) {
      _msg("Error de red al registrar toma", Colors.red);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // HISTORIA DE USUARIO: BOTÓN DE AUXILIO (SOS)
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
              
              // Botón Llamar a Emergencias (911)
              _buildBotonLlamada(
                label: "LLAMAR AL 911",
                color: Colors.red[700]!,
                icon: Icons.local_police,
                onTap: () => _ejecutarLlamada("tel:911"),
              ),
              const SizedBox(height: 16),
              
              // Botón Llamar a Familiar Asignado
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
    } catch (e) {
      print("Error al limpiar preferencias: $e");
    }
    setState(() {
      _estaVinculado = false;
      _adultoMayorId = null;
      _misMedicamentos = [];
      _codigoController.clear();
    });
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
      backgroundColor: Colors.white, // Cambio a color blanco puro para mejorar contraste mecánico de lectura
      appBar: AppBar(
        title: Text(_estaVinculado ? "Mis Medicamentos" : "Configuración"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: _estaVinculado ? [
          IconButton(icon: const Icon(Icons.sync, size: 32), onPressed: _obtenerMisMedicamentos),
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion)
        ] : null,
      ),
      // 🚨 BOTÓN SOS INTEGRADO SIEMPRE VISIBLE EN PANTALLA PRINCIPAL
      floatingActionButton: _estaVinculado ? FloatingActionButton.extended(
        onPressed: _mostrarMenuSOS,
        backgroundColor: Colors.red[700],
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
        label: const Text("¡AYUDA / SOS!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Margen inferior para que el botón SOS no tape el contenido
                  itemCount: _misMedicamentos.length,
                  itemBuilder: (context, index) {
                    final med = _misMedicamentos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 5,
                      color: Colors.blue[50], // Alto contraste visual
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blue[300]!, width: 2)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 26, backgroundColor: Colors.blue[900], child: const Icon(Icons.alarm, size: 30, color: Colors.white)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(med['nombre'] ?? "Sin nombre", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text("Dosis: ${med['dosis'] ?? 'N/A'}", style: const TextStyle(fontSize: 18, color: Colors.black54, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(10)),
                                  child: Text(med['horario'] ?? "00:00", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                )
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // 🟢 HISTORIA DE USUARIO: BOTÓN GRANDE "YA LO TOMÉ" 
                            ElevatedButton.icon(
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
                              label: const Text("✔  YA LO TOMÉ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            )
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
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]),
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
          decoration: const InputDecoration(counterText: "", hintText: "000000", border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
        ),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: _isLoading ? null : _vincularDispositivo,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text("Conectar con mi Familiar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}