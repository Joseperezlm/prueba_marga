import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:marga_app/admin/admin_screen.dart';
import 'package:marga_app/screens/adulto/adulto_mayor_screen.dart';
import 'dart:convert';

// Importaciones del proyecto corregidas
import 'package:marga_app/screens/familiar/familiar_home_screen.dart';
// NUEVA IMPORTACIÓN: Ajusta la ruta si guardaste el archivo en otra carpeta
import 'package:marga_app/screens/registro/registro_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // IP LOCAL UNIFICADA DE TU XAMPP (Asegura conectividad global)
  //final String _loginUrl = "http://10.180.182.89/derek_solutions_api/login.php";
  final String _loginUrl = "http://192.168.1.155/derek_solutions_api/login.php";

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          String rol = data['rol'];
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("¡Bienvenido, ${data['nombre']}!")),
          );

          // Redirección por roles
          if (rol == 'familiar') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FamiliarHomeScreen(
                  familiarId: int.parse(data['id'].toString()),
                  nombreFamiliar: data['nombre'],
                ),
              ),
            );
          } else if (rol == 'administrador') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminScreen(),
              ),
            );
          }
        } else {
          _showErrorSnackbar(data['message'] ?? "Credenciales incorrectas");
        }
      } else {
        _showErrorSnackbar("Error en el servidor (${response.statusCode})");
      }
    } catch (e) {
      _showErrorSnackbar("Error de red: No se pudo conectar al servidor");
      print("Error detallado en login: $e");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 80,
                  color: Colors.blue[700],
                ),
                const SizedBox(height: 16),
                Text(
                  "Derek Solutions",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                Text(
                  "Gestión y Monitoreo de Adherencia Médica",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),

                // Campo Correo
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Por favor ingresa tu correo";
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return "Ingresa un correo electrónico válido";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() { _obscurePassword = !_obscurePassword; });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Por favor ingresa tu contraseña";
                    }
                    if (value.length < 6) {
                      return "La contraseña debe tener al menos 6 caracteres";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Botón Iniciar Sesión (Familiar / Admin)
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Iniciar Sesión", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 25),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("¿Eres Adulto Mayor?", style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 25),

                // BOTÓN EXCLUSIVO PARA EL ADULTO MAYOR CORREGIDO
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdultoMayorScreen()),
                    );
                  },
                  icon: Icon(Icons.pin_outlined, size: 28, color: Colors.green[800]),
                  label: Text(
                    "Ingresar con Código de Cuidador",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[900]),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.green[100],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green[400]!, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // BOTÓN DE REGISTRO INTEGRADO DE MANERA CORRECTA
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegistroScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "¿No tienes una cuenta de Cuidador? Regístrate",
                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}