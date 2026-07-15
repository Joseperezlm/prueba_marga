import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BitacoraScreen extends StatefulWidget {
  final int adultoMayorId;
  const BitacoraScreen({super.key, required this.adultoMayorId});

  @override
  _BitacoraScreenState createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  bool _isLoading = true;
  List<dynamic> _historial = [];
  Map<String, dynamic> _stats = {
    "total": 0,
    "tomados": 0,
    "omitidos": 0,
    "porcentaje_cumplimiento": 100.0
  };

  final String _baseUri = "http://192.168.1.155/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    _cargarDatosBitacora();
  }

  Future<void> _cargarDatosBitacora() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(Uri.parse("${_baseUri}obtener_bitacora.php?adulto_mayor_id=${widget.adultoMayorId}"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _historial = data['historial'] ?? [];
            _stats = data['estadisticas'] ?? _stats;
          });
        }
      }
    } catch (e) {
      print("Error cargando bitácora: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    double cumplimiento = double.tryParse(_stats['porcentaje_cumplimiento'].toString()) ?? 100.0;
    Color colorDesempeno = cumplimiento >= 80 
        ? Colors.green 
        : (cumplimiento >= 50 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bitácora de Monitoreo"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _cargarDatosBitacora,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- SECCIÓN ESTADÍSTICA ---
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            "Desempeño y Cumplimiento",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: cumplimiento / 100,
                                  strokeWidth: 10,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(colorDesempeno),
                                ),
                              ),
                              Text(
                                "$cumplimiento%",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorDesempeno),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn("Programadas", _stats['total'].toString(), Colors.blue),
                              _buildStatColumn("Tomadas", _stats['tomados'].toString(), Colors.green),
                              _buildStatColumn("Omitidas", _stats['omitidos'].toString(), Colors.red),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            cumplimiento >= 80 
                                ? "¡Excelente! Estado de salud muy estable." 
                                : "Atención: Se han registrado olvidos recurrentes.",
                            style: TextStyle(fontWeight: FontWeight.w600, color: colorDesempeno, fontSize: 15),
                            textAlign: TextAlign.center,
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- LISTADO DE HISTORIAL ---
                  Text(
                    "Historial de tomas recientes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                  const SizedBox(height: 10),
                  _historial.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Text("Aún no hay registros de tomas en la bitácora.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _historial.length,
                          itemBuilder: (context, index) {
                            final toma = _historial[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: toma['estado'] == 'tomado' ? Colors.green[100] : Colors.red[100],
                                  child: Icon(
                                    toma['estado'] == 'tomado' ? Icons.check : Icons.close,
                                    color: toma['estado'] == 'tomado' ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  toma['nombre_medicamento'] ?? 'Medicamento',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text("Fecha: ${toma['fecha_toma']}  •  Hora: ${toma['hora_toma']}"),
                                trailing: Text(
                                  toma['estado'] == 'tomado' ? 'TOMADO' : 'OMITIDO',
                                  style: TextStyle(
                                    color: toma['estado'] == 'tomado' ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}