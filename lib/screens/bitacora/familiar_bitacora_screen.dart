import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FamiliarBitacoraScreen extends StatefulWidget {
  final int familiarId;
  
  const FamiliarBitacoraScreen({
    super.key,
    required this.familiarId,
  });

  @override
  _FamiliarBitacoraScreenState createState() => _FamiliarBitacoraScreenState();
}

class _FamiliarBitacoraScreenState extends State<FamiliarBitacoraScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  List<dynamic> _adultos = [];
  List<dynamic> _medicamentos = [];
  List<dynamic> _historial = [];
  List<dynamic> _lineaTiempo = [];
  Map<String, dynamic> _estadisticas = {};
  
  final String _baseUri = "http://192.168.1.155/derek_solutions_api/";
  int _diasSeleccionados = 7;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() { _isLoading = true; });
    try {
      final url = "${_baseUri}obtener_bitacora_familiar.php?familiar_id=${widget.familiarId}&dias=$_diasSeleccionados";
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _adultos = data['adultos'] ?? [];
            _medicamentos = data['medicamentos'] ?? [];
            _historial = data['historial'] ?? [];
            _lineaTiempo = data['linea_tiempo'] ?? [];
            _estadisticas = data['estadisticas'] ?? {};
          });
        }
      }
    } catch (e) {
      print("Error cargando bitácora: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar datos: $e")),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _exportarReporte() async {
    setState(() { _isExporting = true; });
    try {
      // Generar contenido del reporte
      String reporte = _generarContenidoReporte();
      
      // Guardar en archivo
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/reporte_bitacora_${DateTime.now().format()}.txt';
      final file = File(path);
      await file.writeAsString(reporte);
      
      // Compartir archivo
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Reporte de Bitácora - ${DateTime.now().format()}',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reporte exportado exitosamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al exportar: $e")),
      );
    } finally {
      setState(() { _isExporting = false; });
    }
  }

  String _generarContenidoReporte() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('=== REPORTE DE BITÁCORA ===');
    buffer.writeln('Fecha: ${DateTime.now().format()}');
    buffer.writeln('Período: Últimos $_diasSeleccionados días');
    buffer.writeln('=' * 40);
    buffer.writeln('');
    
    buffer.writeln('📊 ESTADÍSTICAS GENERALES');
    buffer.writeln('- Total medicamentos: ${_estadisticas['total_medicamentos'] ?? 0}');
    buffer.writeln('- Tomados: ${_estadisticas['tomados'] ?? 0}');
    buffer.writeln('- Omitidos: ${_estadisticas['omitidos'] ?? 0}');
    buffer.writeln('- Cumplimiento: ${_estadisticas['porcentaje_cumplimiento'] ?? 0}%');
    buffer.writeln('');
    
    buffer.writeln('👴 DESGLOSE POR ADULTO MAYOR');
    var porAdulto = _estadisticas['por_adulto'] ?? {};
    porAdulto.forEach((id, data) {
      buffer.writeln('--- ${data['nombre']} ---');
      buffer.writeln('  Total: ${data['total']}');
      buffer.writeln('  Tomados: ${data['tomados']}');
      buffer.writeln('  Omitidos: ${data['omitidos']}');
      buffer.writeln('');
    });
    
    buffer.writeln('💊 LISTADO DE MEDICAMENTOS');
    buffer.writeln('${"Adulto".padRight(20)} | ${"Medicamento".padRight(25)} | ${"Dosis".padRight(15)} | ${"Horario".padRight(10)} | Estado');
    buffer.writeln('-' * 85);
    for (var med in _medicamentos) {
      String estado = med['tomado_hoy'] == true ? '✅ Tomado' : '⏳ Pendiente';
      buffer.writeln(
        '${(med['adulto_nombre'] ?? 'N/A').padRight(20)} | '
        '${(med['nombre'] ?? 'N/A').padRight(25)} | '
        '${(med['dosis'] ?? 'N/A').padRight(15)} | '
        '${(med['horario'] ?? '00:00').substring(0, 5).padRight(10)} | '
        '$estado'
      );
    }
    buffer.writeln('');
    
    buffer.writeln('📅 HISTORIAL DE TOMAS');
    if (_historial.isNotEmpty) {
      for (var toma in _historial) {
        buffer.writeln(
          '${toma['fecha_toma']} ${toma['hora_toma']} - ${toma['adulto_nombre']}: ${toma['medicamento_nombre']}'
        );
      }
    } else {
      buffer.writeln('No hay registros en el período seleccionado.');
    }
    buffer.writeln('');
    buffer.writeln('=== FIN DEL REPORTE ===');
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    double cumplimiento = (_estadisticas['porcentaje_cumplimiento'] ?? 0).toDouble();
    Color colorDesempeno = cumplimiento >= 80 
        ? Colors.green 
        : (cumplimiento >= 50 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bitácora Familiar"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          // Botón de exportar
          IconButton(
            icon: _isExporting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.file_download),
            tooltip: 'Exportar Reporte',
            onPressed: _isExporting ? null : _exportarReporte,
          ),
          // Botón de actualizar
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de días
                    Row(
                      children: [
                        const Text("Período:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        _buildDiasSelector(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Tarjeta de estadísticas generales
                    _buildEstadisticasCard(cumplimiento, colorDesempeno),
                    const SizedBox(height: 16),
                    
                    // Desglose por adulto mayor
                    _buildDesgloseAdultos(),
                    const SizedBox(height: 16),
                    
                    // Línea de tiempo
                    _buildLineaTiempo(),
                    const SizedBox(height: 16),
                    
                    // Lista de medicamentos
                    _buildListaMedicamentos(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDiasSelector() {
    return DropdownButton<int>(
      value: _diasSeleccionados,
      style: const TextStyle(color: Colors.blue),
      underline: Container(height: 1, color: Colors.blue),
      items: const [
        DropdownMenuItem(value: 7, child: Text("7 días")),
        DropdownMenuItem(value: 15, child: Text("15 días")),
        DropdownMenuItem(value: 30, child: Text("30 días")),
        DropdownMenuItem(value: 60, child: Text("60 días")),
        DropdownMenuItem(value: 90, child: Text("90 días")),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() { _diasSeleccionados = value; });
          _cargarDatos();
        }
      },
    );
  }

  Widget _buildEstadisticasCard(double cumplimiento, Color colorDesempeno) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "📊 Resumen General",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("💊", "Medicamentos", _estadisticas['total_medicamentos']?.toString() ?? '0', Colors.blue),
                _buildStatItem("✅", "Tomados", _estadisticas['tomados']?.toString() ?? '0', Colors.green),
                _buildStatItem("❌", "Omitidos", _estadisticas['omitidos']?.toString() ?? '0', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: cumplimiento / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(colorDesempeno),
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "$cumplimiento%",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorDesempeno,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cumplimiento >= 80 
                  ? "✅ Excelente adherencia al tratamiento" 
                  : cumplimiento >= 50 
                      ? "⚠️ Adherencia regular, requiere atención" 
                      : "🔴 Adherencia crítica, necesita intervención",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorDesempeno,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String icon, String label, String value, Color color) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDesgloseAdultos() {
    var porAdulto = _estadisticas['por_adulto'] ?? {};
    if (porAdulto.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "👴 Desglose por Adulto Mayor",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...porAdulto.entries.map((entry) {
              var data = entry.value as Map<String, dynamic>;
              double porcentaje = data['total'] > 0 
                  ? (data['tomados'] / data['total']) * 100 
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data['nombre'] ?? 'Adulto',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          "${data['tomados']}/${data['total']} (${porcentaje.toStringAsFixed(0)}%)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: porcentaje >= 80 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: data['total'] > 0 ? data['tomados'] / data['total'] : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        porcentaje >= 80 ? Colors.green : Colors.orange,
                      ),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLineaTiempo() {
    if (_lineaTiempo.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📅 Línea de Tiempo",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _lineaTiempo.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  var dia = _lineaTiempo[index];
                  int tomados = dia['tomados'] ?? 0;
                  int pendientes = dia['pendientes'] ?? 0;
                  int total = tomados + pendientes;
                  double porcentaje = total > 0 ? tomados / total : 0;
                  
                  return Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (porcentaje > 0)
                              Container(
                                width: 30,
                                height: porcentaje * 70,
                                decoration: BoxDecoration(
                                  color: porcentaje >= 0.8 ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dia['fecha_formateada'] ?? '',
                        style: const TextStyle(fontSize: 10),
                      ),
                      Text(
                        "$tomados/$total",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: porcentaje >= 0.8 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaMedicamentos() {
    if (_medicamentos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              "No hay medicamentos registrados",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "💊 Medicamentos Asignados",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.blue[50]),
                columns: const [
                  DataColumn(label: Text("Adulto", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Medicamento", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Dosis", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Horario", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Estado Hoy", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _medicamentos.map((med) {
                  bool tomado = med['tomado_hoy'] ?? false;
                  return DataRow(
                    cells: [
                      DataCell(Text(med['adulto_nombre'] ?? 'N/A')),
                      DataCell(Text(med['nombre'] ?? 'N/A')),
                      DataCell(Text(med['dosis'] ?? 'N/A')),
                      DataCell(Text((med['horario'] ?? '00:00').toString().substring(0, 5))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tomado ? Colors.green[100] : Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tomado ? '✅ Tomado' : '⏳ Pendiente',
                            style: TextStyle(
                              color: tomado ? Colors.green[700] : Colors.orange[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extensión para formatear DateTime
extension DateTimeFormat on DateTime {
  String format() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}