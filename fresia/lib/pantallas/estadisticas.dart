import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home.dart';

class Estadisticas extends StatefulWidget {
  const Estadisticas({super.key});

  @override
  State<Estadisticas> createState() => _EstadisticasState();
}

class _EstadisticasState extends State<Estadisticas> {
  final bluetooth = FlutterBluetoothSerial.instance;
  bool estado = false; // Estado del Bluetooth
  bool conectado = false; // BT no conectado
  BluetoothConnection? conexion; // Conexión
  List<BluetoothDevice>? dispositivos = [];
  BluetoothDevice? activo;

  Future<void> _solicitarPermisos() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos Bluetooth denegados')),
      );
    }
  }

  void _estadoBT() {
    bluetooth.state.then((value) {
      setState(() {
        estado = value.isEnabled;
      });
    });
    bluetooth.onStateChanged().listen((event) {
      setState(() {
        switch (event) {
          case BluetoothState.STATE_ON:
            estado = true;
            leerDispositivos();
            break;
          case BluetoothState.STATE_OFF:
            estado = false;
            break;
          case BluetoothState.STATE_BLE_TURNING_OFF:
            debugPrint("Se está apagando el BT");
            break;
          case BluetoothState.STATE_BLE_TURNING_ON:
            debugPrint("Se está encendiendo el BT");
            break;
          default:
            break;
        }
      });
    });
  }

  void encender() async {
    await _solicitarPermisos();
    await bluetooth.requestEnable();
  }

  void apagar() async {
    await bluetooth.requestDisable();
  }

  Widget botonBT() {
    return SwitchListTile(
      value: estado,
      title: Text(estado ? "Encendido" : "Apagado"),
      tileColor: estado ? Colors.blue : Colors.grey,
      secondary: estado
          ? const Icon(Icons.bluetooth)
          : const Icon(Icons.bluetooth_disabled),
      onChanged: (value) {
        setState(() {
          if (value) {
            encender();
          } else {
            apagar();
          }
          estado = value;
          leerDispositivos();
        });
      },
    );
  }

  void leerDispositivos() async {
    dispositivos = await bluetooth.getBondedDevices();
    setState(() {}); // Actualiza el estado para que la lista se vuelva a construir
    if (dispositivos != null && dispositivos!.isNotEmpty) {
      debugPrint(dispositivos![0].name);
      debugPrint(dispositivos![0].address);
    } else {
      debugPrint("No se encontraron dispositivos vinculados.");
    }
  }

  Widget lista() {
    if (dispositivos == null || dispositivos!.isEmpty) {
      return const Center(child: Text("No hay dispositivos vinculados."));
    } else {
      return ListView.builder(
        itemCount: dispositivos!.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: IconButton(
              icon: const Icon(Icons.bluetooth),
              onPressed: () async {
                try {
                  // Conectar al dispositivo Bluetooth
                  conexion = await BluetoothConnection.toAddress(dispositivos![index].address);
                  conectado = true;
                  activo = dispositivos![index];
                  setState(() {});

                  // Navegar a Home y pasar la conexión Bluetooth
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Home(conexion: conexion),
                    ),
                  );
                } catch (e) {
                  debugPrint('Error al conectar: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al conectar: $e')),
                  );
                }
              },
            ),
            trailing: Text(
              dispositivos![index].address ?? '',
              style: const TextStyle(color: Colors.green, fontSize: 15),
            ),
            title: Text(dispositivos![index].name ?? 'Unknown'),
          );
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _solicitarPermisos();
    _estadoBT();
  }

  Widget dispositivo() {
    return ListTile(
      title: activo == null ? const Text("No conectado") : Text("${activo?.name}"),
      subtitle: activo == null ? const Text("No Mac address") : Text("${activo?.address}"),
      leading: activo == null
          ? IconButton(
        onPressed: () {
          leerDispositivos(); // Muestra la lista de los dispositivos
        },
        icon: const Icon(Icons.search),
      )
          : IconButton(
        onPressed: () {
          // Desconectar el dispositivo Bluetooth
          activo = null;
          conectado = false;
          dispositivos = [];
          conexion?.finish();
          setState(() {});
        },
        icon: const Icon(Icons.delete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            botonBT(),
            const Divider(height: 5),
            dispositivo(),
            const Divider(height: 5),
            Expanded(child: lista()),
            const Divider(height: 5),
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
        onTap: (index) {
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
        },
      ),
    );
  }
}
