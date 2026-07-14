import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GenerarCodigoScreen extends StatefulWidget {
  final int familiarId;
  const GenerarCodigoScreen({super.key, required this.familiarId});

  @override
  _GenerarCodigoScreenState createState() => _GenerarCodigoScreenState();
}

class _GenerarCodigoScreenState extends State<GenerarCodigoScreen> {
  final TextEditingController _nombreAdultoController = TextEditingController();
  String _codigoGenerado = "";
  bool _isLoading = false;

  final String _apiUrl = "http://10.180.182.89/derek_solutions_api/crear_vinculacion.php";

  Future<void> _generarCodigo() async {
    if (_nombreAdultoController.text.trim().isEmpty) return;
    setState(() { _isLoading = true; });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "familiar_id": widget.familiarId,
          "nombre": _nombreAdultoController.text.trim()
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _codigoGenerado = data['codigo']; 
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Error desconocido"), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error en el servidor (${response.statusCode})."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al conectar con el servidor."), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vincular Adulto Mayor"), 
        backgroundColor: Colors.blue[700], 
        foregroundColor: Colors.white,
        // Evitamos que el usuario regrese con la flecha estándar sin avisar de la actualización
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _codigoGenerado.isNotEmpty),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_codigoGenerado.isEmpty) ...[
              const Text(
                "Registra el nombre de la persona de la tercera edad para generar su clave de acceso único.", 
                style: TextStyle(fontSize: 15, color: Colors.grey)
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nombreAdultoController,
                decoration: const InputDecoration(
                  labelText: "Nombre del Adulto Mayor (Ej: Abuela María)", 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.person_outline)
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _generarCodigo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16), 
                  backgroundColor: Colors.blue[700], 
                  foregroundColor: Colors.white
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ) 
                    : const Text("Generar Código de Enlace"),
              ),
            ] else ...[
              Card(
                color: Colors.blue[50], 
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: Colors.blue.withValues(alpha: 0.3))
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Proporciona este código en el dispositivo del adulto mayor al abrir su aplicación por primera vez.", 
                          style: TextStyle(fontSize: 14, color: Colors.blue[900])
                        )
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                "CÓDIGO DE ENLACE", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2)
              ),
              const SizedBox(height: 10),
              Text(
                _codigoGenerado,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.green[800]),
              ),
              const Spacer(),
              ElevatedButton(
                // Retornamos true para indicar que la creación fue exitosa y reactivar los layouts
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16), 
                  backgroundColor: Colors.blue[700], 
                  foregroundColor: Colors.white
                ),
                child: const Text("Terminar y Salir"),
              )
            ]
          ],
        ),
      ),
    );
  }
}