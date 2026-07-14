import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool isLoading = true;
  List<dynamic> vinculaciones = [];

  final String baseUri = "http://10.180.182.89/derek_solutions_api/";

  @override
  void initState() {
    super.initState();
    obtenerVinculaciones();
  }

  Future<void> obtenerVinculaciones() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await http.get(
        Uri.parse("${baseUri}obtener_vinculaciones_admin.php"),
      );

      print(response.body);
      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        setState(() {
          vinculaciones = data["vinculaciones"];
        });
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al obtener vinculaciones"),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  int get totalActivos {
    return vinculaciones.where((v) => v["estado"] == "activo").length;
  }

  int get totalPendientes {
    return vinculaciones.where((v) => v["estado"] == "pendiente").length;
  }

  // Función para cerrar la sesión y regresar al Login
  void cerrarSesion() {
    // Si manejas SharedPreferences o tokens, bórralos aquí antes de navegar.
    
    // Opción A: Si usas rutas nombradas (reemplaza '/' por tu ruta de login)
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

    // Opción B: Si usas navegación directa por clase (descomenta si usas esta)
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => const LoginScreen()), // Tu vista de login
    //   (route) => false,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Panel de Administrador"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: obtenerVinculaciones,
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar",
          ),
          // Botón de salir agregado aquí
          IconButton(
            onPressed: cerrarSesion,
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.link,
                                  size: 40,
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${vinculaciones.length}",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text("Vinculaciones"),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 40,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "$totalActivos",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text("Activas"),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.pending,
                                  size: 40,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "$totalPendientes",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text("Pendientes"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: vinculaciones.isEmpty
                      ? const Center(
                          child: Text(
                            "No existen vinculaciones",
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : ListView.builder(
                          itemCount: vinculaciones.length,
                          itemBuilder: (context, index) {
                            final item = vinculaciones[index];
                            final estado = item["estado"].toString();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              elevation: 3,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: estado == "activo"
                                      ? Colors.green
                                      : Colors.orange,
                                  child: const Icon(
                                    Icons.people,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  item["familiar_nombre"].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Text("Adulto mayor: ${item["adulto_nombre"]}"),
                                    Text("Estado: $estado"),
                                    Text("Código: ${item["codigo_vinculacion"]}"),
                                  ],
                                ),
                                trailing: estado == "activo"
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : const Icon(Icons.pending, color: Colors.orange),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}