import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marga_app/screens/bitacora/familiar_bitacora_screen.dart';
import 'package:marga_app/screens/login/login_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:marga_app/screens/medicamento/agregar_medicamento_screen.dart';
import 'package:marga_app/screens/codigo/generar_codigo_screen.dart';

class FamiliarHomeScreen extends StatefulWidget {
  final int familiarId;
  final String nombreFamiliar;

  const FamiliarHomeScreen({
    super.key,
    required this.familiarId,
    required this.nombreFamiliar,
  });

  @override
  _FamiliarHomeScreenState createState() => _FamiliarHomeScreenState();
}

class _FamiliarHomeScreenState extends State<FamiliarHomeScreen> {
  bool _isLoading = true;
  List<dynamic> _medicamentosAsignados = [];

  //final String _baseUri = "http://10.180.182.89/derek_solutions_api/";
  final String _baseUri = "http://192.168.1.155/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    _obtenerMedicamentosGlobales();
  }

  Future<void> _obtenerMedicamentosGlobales() async {
  setState(() { _isLoading = true; });
  try {
    final urlCompleta = "${_baseUri}obtener_medicamentos_familiar.php?familiar_id=${widget.familiarId}";

    
    print("[DEBUG] ===== INICIO PETICIÓN =====");
    print("[DEBUG] familiar_id: ${widget.familiarId}");
    print("[DEBUG] URL completa: $urlCompleta");
    print("[DEBUG] ============================");

    final response = await http.get(Uri.parse(urlCompleta));

    print("[DEBUG] Status code: ${response.statusCode}");
    print("[DEBUG] Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("[DEBUG] Data parseada: $data");
      
      if (data['success'] == true) {
        if (data['medicamentos'] != null && data['medicamentos'] is List) {
          setState(() {
            _medicamentosAsignados = data['medicamentos'];
          });
          print("[DEBUG] Medicamentos cargados: ${_medicamentosAsignados.length}");
        } else {
          print("[DEBUG] No hay medicamentos o el formato es incorrecto");
          setState(() {
            _medicamentosAsignados = [];
          });
        }
      } else {
        print("[DEBUG] Error en backend: ${data['message'] ?? 'Error desconocido'}");
        setState(() {
          _medicamentosAsignados = [];
        });
      }
    } else {
      print("[DEBUG] Error HTTP: ${response.statusCode}");
      setState(() {
        _medicamentosAsignados = [];
      });
    }
  } catch (e) {
    print("[DEBUG] Excepción capturada: $e");
    setState(() {
      _medicamentosAsignados = [];
    });
  } finally {
    setState(() { _isLoading = false; });
    print("[DEBUG] ===== FIN PETICIÓN =====");
  }
}

// Después de _obtenerMedicamentosGlobales, agrega esta función:
Future<void> _diagnosticarConexion() async {
  try {
    // Asegúrate de usar el nombre correcto de tu archivo PHP
    final url = "${_baseUri}obtener_medicamentos_familiar.php?familiar_id=${widget.familiarId}";
    final response = await http.get(Uri.parse(url));
    
    print("=== DIAGNÓSTICO ===");
    print("URL: $url");
    print("Status: ${response.statusCode}");
    print("Body completo: ${response.body}");
    print("==================");
    
    // Mostrar en un diálogo
    try {
      final data = jsonDecode(response.body);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Diagnóstico de Conexión"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Familiar ID: ${widget.familiarId}"),
                const Divider(),
                Text("Status HTTP: ${response.statusCode}"),
                Text("Success: ${data['success'] ?? 'N/A'}"),
                Text("Medicamentos: ${(data['medicamentos'] as List?)?.length ?? 0}"),
                if (data['mensaje'] != null) 
                  Text("Mensaje: ${data['mensaje']}", style: TextStyle(color: Colors.orange)),
                if (data['debug'] != null)
                  Text("Debug: ${data['debug']}"),
                const SizedBox(height: 10),
                const Text("Respuesta completa:", style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  constraints: BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      response.body.length > 500 
                        ? '${response.body.substring(0, 500)}...\n(Truncado)'
                        : response.body,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _obtenerMedicamentosGlobales();
              },
              child: const Text("Reintentar"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Si no se puede parsear el JSON
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error de Diagnóstico"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Error: $e"),
              const SizedBox(height: 10),
              Text("Respuesta: ${response.body}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    print("Error diagnóstico: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error de diagnóstico: $e")),
    );
  }
}

  Future<void> _eliminarMedicamentoBackend(int medicamentoId) async {
    try {
      final response = await http.post(
        Uri.parse("${_baseUri}eliminar_medicamento.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": medicamentoId}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medicamento eliminado con éxito"), backgroundColor: Colors.green),
        );
        _obtenerMedicamentosGlobales();
      } else {
        _mostrarErrorSnackbar(data['message'] ?? "No se pudo eliminar el medicamento");
      }
    } catch (e) {
      _mostrarErrorSnackbar("Error de red al intentar eliminar");
    }
  }

  void _confirmarEliminacion(int id, String nombreMed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar Medicamento?"),
        content: Text("¿Estás seguro de que deseas eliminar $nombreMed del registro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarMedicamentoBackend(id);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editarMedicamento(Map<String, dynamic> med) async {
    final bool? seActualizo = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgregarMedicamentoScreen(
          familiarId: widget.familiarId,
          medicamento: med, 
        ),
      ),
    );

    if (seActualizo == true) {
      _obtenerMedicamentosGlobales(); 
    }
  }

  Future<void> _cerrarSesionFamiliar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 
    } catch (e) {
      print("Error al limpiar datos locales: $e");
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _mostrarErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
  title: Text("Hola, ${widget.nombreFamiliar}"),
  backgroundColor: Colors.blue[700],
  foregroundColor: Colors.white,
  // En la AppBar de FamiliarHomeScreen, agrega el botón de bitácora
actions: [
  // Botón de Bitácora
  IconButton(
    icon: const Icon(Icons.assessment),
    tooltip: 'Bitácora Familiar',
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FamiliarBitacoraScreen(
            familiarId: widget.familiarId,
          ),
        ),
      );
    },
  ),
  // Botón Actualizar
  IconButton(
    icon: const Icon(Icons.refresh),
    tooltip: 'Actualizar Medicamentos',
    onPressed: _obtenerMedicamentosGlobales,
  ),
  // Botón Diagnóstico
  IconButton(
    icon: const Icon(Icons.bug_report),
    tooltip: 'Diagnóstico',
    onPressed: _diagnosticarConexion,
  ),
  // Botón Cerrar Sesión
  // En el AppBar, el botón de cerrar sesión debe tener:
IconButton(
  icon: const Icon(Icons.logout),
  tooltip: 'Cerrar Sesión',
  onPressed: () {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Cerrar Sesión"),
          content: const Text("¿Estás seguro de que deseas salir del perfil familiar?"),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Salir", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _cerrarSesionFamiliar(); // ✅ Esta línea debe estar presente
              },
            ),
          ],
        );
      },
    );
  },
)
],
),
      body: RefreshIndicator(
        onRefresh: _obtenerMedicamentosGlobales,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Acciones de Gestión",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMenuButton(
                      context,
                      icon: Icons.medical_services_outlined,
                      label: "Agregar\nMedicamento",
                      color: Colors.green,
                      onTap: () async {
                        final bool? resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AgregarMedicamentoScreen(familiarId: widget.familiarId)),
                        );
                        if (resultado == true) {
                          _obtenerMedicamentosGlobales();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMenuButton(
                      context,
                      icon: Icons.qr_code_scanner_outlined,
                      label: "Vincular\nAdulto Mayor",
                      color: Colors.blue,
                      onTap: () async {
                        final bool? seAgregoNuevo = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GenerarCodigoScreen(familiarId: widget.familiarId)),
                        );
                        if (seAgregoNuevo == true) {
                          _obtenerMedicamentosGlobales();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Text(
                "Medicamentos Asignados Actuales",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _medicamentosAsignados.isEmpty
                        ? ListView(children: [const SizedBox(height: 50), _buildEmptyState()])
                        : ListView.builder(
                            itemCount: _medicamentosAsignados.length,
                            itemBuilder: (context, index) {
                              final med = _medicamentosAsignados[index];
                              return _buildMedicamentoCard(med);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildMedicamentoCard(Map<String, dynamic> med) {
  // Determinar el estado y color
  String estado = med['estado'] ?? 'pendiente';
  Color estadoColor = estado == 'tomado' ? Colors.green : Colors.orange;
  String estadoTexto = estado == 'tomado' ? '✓ Tomado' : '⏳ Pendiente';
  
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: estadoColor.withValues(alpha: 0.2),
        child: Icon(
          estado == 'tomado' ? Icons.check_circle : Icons.access_time,
          color: estadoColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              med['nombre'] ?? "Sin nombre",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              estadoTexto,
              style: TextStyle(color: estadoColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Dosis: ${med['dosis'] ?? 'N/A'}"),
          if (med['nombre_adulto'] != null && med['nombre_adulto'].isNotEmpty)
            Text(
              "Para: ${med['nombre_adulto']}",
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.blue),
            ),
          if (med['hora_toma_real'] != null)
            Text(
              "Tomado a las: ${med['hora_toma_real']}",
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: BorderRadius.circular(8)
            ),
            child: Text(
              med['horario'] ?? "00:00",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'editar') {
                _editarMedicamento(med);
              } else if (value == 'eliminar') {
                int idMed = int.parse(med['id'].toString());
                _confirmarEliminacion(idMed, med['nombre'] ?? 'Medicamento');
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'editar',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text("Editar"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'eliminar',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text("Eliminar", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // En tu _buildEmptyState, mejora el mensaje:
Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 10),
        Text(
          "No hay medicamentos asignados aún.",
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Text(
          "Vincula un adulto mayor para ver sus medicamentos.",
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    ),
  );
}
}