import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  // 1. Creamos un FocusNode para el campo de contraseña
  // (El de usuario no lo necesita porque usaremos autofocus)
  final FocusNode _passFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _passFocusNode.dispose();
    super.dispose();
  }

  void _doLogin() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingrese usuario y contraseña")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulamos un pequeño delay de red o validación real
    await Future.delayed(const Duration(milliseconds: 800));

    // AQUÍ IRÍA TU LÓGICA REAL DE AUTH CON EL BACKEND
    // Por ahora, validamos "hardcodeado" o simplemente dejamos pasar
    // para que veas el flujo.
    
    if (mounted) {
      final appProvider = context.read<AppProvider>();
      
      // Si usas la lógica del AppProvider para web:
      appProvider.webLogin(true); 
      
      // O si navegas directamente:
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Fondo suave
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: 400, // Ancho fijo para que se vea bien en PC/Web
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_person, size: 64, color: Colors.brown),
                  const Gap(16),
                  const Text(
                    "Bienvenido",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Sistema de Administración de Datos",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Gap(32),

                  // --- CAMPO USUARIO ---
                  TextFormField(
                    controller: _userCtrl,
                    // 2. MAGIA AQUÍ: autofocus true pone el cursor aquí al iniciar
                    autofocus: true, 
                    
                    // 3. Configurar "Enter" para ir al siguiente campo
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      // Al dar Enter, movemos el foco al password
                      FocusScope.of(context).requestFocus(_passFocusNode);
                    },
                    
                    decoration: InputDecoration(
                      labelText: "Usuario",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Gap(16),

                  // --- CAMPO CONTRASEÑA ---
                  TextFormField(
                    controller: _passCtrl,
                    focusNode: _passFocusNode, // Asignamos el nodo para recibir el foco
                    obscureText: _obscurePass,
                    
                    // 4. Configurar "Enter" para ENVIAR el formulario
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      // Al dar Enter aquí, intentamos loguear
                      _doLogin();
                    },

                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Gap(24),

                  // BOTÓN DE LOGIN
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _doLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Ingresar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}