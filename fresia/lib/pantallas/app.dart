import 'package:flutter/material.dart';
import 'package:fresia/pantallas/registro.dart';
import 'estadisticas.dart';
import 'fresia.dart';
import 'home.dart';
import 'login.dart';

class App extends StatelessWidget {
  const App({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/login",
      theme: ThemeData(
        primaryColor: Colors.lightBlue,
        buttonTheme: const ButtonThemeData(
          buttonColor: Colors.lightBlue, // Color de fondo de los botones
          textTheme: ButtonTextTheme.primary, // Color de texto
        ),
        appBarTheme: const AppBarTheme(
          color: Colors.lightBlue,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Puedes añadir más personalizaciones aquí
      ),
      routes: {
        "/login": (context) => const Login(),
        "/": (context) => const Home(conexion: null),
        "registro": (context) => const Registro(),
        "estadisticas": (context) => const Estadisticas(),
        "fresia": (context) => const Fresia(),
      },
    );
  }
}
