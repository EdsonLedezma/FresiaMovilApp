import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../widgets/mic_list.dart';


class Home extends StatefulWidget {
  final BluetoothConnection? conexion; // Recibe la conexión Bluetooth

  const Home({super.key, required this.conexion});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    // Asegúrate de que la conexión no sea nula
    if (widget.conexion == null) {
      // Manejar el caso de conexión nula si es necesario
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushNamed(context, 'estadisticas');
        break;
      case 1:
        Navigator.pushNamed(context, '/');
        break;
      case 2:
        Navigator.pushNamed(context, 'fresia');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido a Fres IA'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Añade espaciado alrededor del contenido
        child: Column(
          children: <Widget>[
            Expanded(
              child: widget.conexion != null && widget.conexion!.isConnected
                  ? MicList(conexion: widget.conexion) // Pasar la conexión al widget MicList
                  : Center(child: CircularProgressIndicator()), // Muestra un indicador de carga si no está conectado
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_audio),
            label: 'BT análisis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_exploration_outlined),
            label: 'Fresia',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.conexion != null) {
      // Cerrar la conexión de forma segura
    }
    super.dispose();
  }
}