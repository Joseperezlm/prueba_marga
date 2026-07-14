import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  final String _baseUri = "http://10.180.182.89/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    _obtenerMedicamentosGlobales();
  }

  Future<void> _obtenerMedicamentosGlobales() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(
        Uri.parse("${_baseUri}obtener_medicamentos_adulto.php?familiar_id=${widget.familiarId}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _medicamentosAsignados = data['medicamentos'];
          });
        }
      }
    } catch (e) {
      print("Error de red al obtener medicamentos: $e");
      setState(() {
        _medicamentosAsignados = [
          {"id": 1, "nombre": "Paracetamol", "dosis": "1 tableta de 500mg", "horario": "08:00:00", "paciente": "Abuelo Luis", "adulto_mayor_id": 101, "recurrencia_horas": 8},
          {"id": 2, "nombre": "Metformina", "dosis": "Media tableta", "horario": "14:00:00", "paciente": "Abuela María", "adulto_mayor_id": 102, "recurrencia_horas": 12},
        ];
      });
    } finally {
      setState(() { _isLoading = false; });
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

  // INTEGRADO: Redirección real compartiendo el mismo formulario tipo Upsert
  void _editarMedicamento(Map<String, dynamic> med) async {
    final bool? seActualizo = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgregarMedicamentoScreen(
          familiarId: widget.familiarId,
          medicamento: med, // Enviamos el mapa para activar el "Modo Edición"
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Medicamentos',
            onPressed: _obtenerMedicamentosGlobales,
          ),
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
                          _cerrarSesionFamiliar();
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: Icon(Icons.vaccines_outlined, color: Colors.blue[700]),
        ),
        title: Text(med['nombre'] ?? "Sin nombre", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dosis: ${med['dosis'] ?? 'N/A'}"),
            if (med['paciente'] != null)
              Text("Para: ${med['paciente']}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(8)),
              child: Text(med['horario'] ?? "00:00", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text("No hay medicamentos asignados aún.", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}