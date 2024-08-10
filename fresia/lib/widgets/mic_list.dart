import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MicList extends StatefulWidget {
  final BluetoothConnection? conexion;

  const MicList({super.key, required this.conexion});

  @override
  MicListState createState() => MicListState();
}

class MicListState extends State<MicList> {
  List<String> micLabels = [
    "Etiqueta el microfono 1",
    "Etiqueta el microfono 2",
    "Etiqueta el microfono 3",
    "Etiqueta el microfono 4"
  ];

  List<bool> isAudioReady = [false, false, false, false];
  String vehicleBrand = "";
  AudioPlayer audioPlayer = AudioPlayer();
  StreamSubscription<Uint8List>? _audioSubscription;

  // Parámetros de audio
  int sampleRate = 44100;  // Frecuencia de muestreo
  int numChannels = 1;      // Número de canales (1 para mono)
  int bitsPerSample = 16;   // Bits por muestra
  int totalDataSize = 0;    // Tamaño total de los datos de audio

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
    createWavFiles();
  }

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  Future<void> createWavFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    for (int i = 1; i <= 4; i++) {
      final filePath = '${directory.path}/mic_$i.wav';
      final file = File(filePath);
      // Crear el archivo WAV con un encabezado vacío
      await file.writeAsBytes(createWavHeader(0)); // Inicializa con 0 bytes de datos
      print("Archivo creado: $filePath");
    }
  }

  Uint8List createWavHeader(int dataSize) {
    int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    List<int> header = [];

    header.addAll('RIFF'.codeUnits);
    header.addAll((36 + dataSize).toBytes(4));
    header.addAll('WAVE'.codeUnits);

    header.addAll('fmt '.codeUnits);
    header.addAll((16).toBytes(4)); // Subchunk1Size para PCM
    header.addAll((1).toBytes(2)); // AudioFormat (PCM)
    header.addAll((numChannels).toBytes(2));
    header.addAll((sampleRate).toBytes(4));
    header.addAll((byteRate).toBytes(4));
    header.addAll(((numChannels * bitsPerSample) ~/ 8).toBytes(2)); // BlockAlign
    header.addAll((bitsPerSample).toBytes(2));

    header.addAll('data'.codeUnits);
    header.addAll(dataSize.toBytes(4)); // Subchunk2Size

    return Uint8List.fromList(header);
  }

  void changeMic(int micNumber) async {
    if (widget.conexion != null && widget.conexion!.isConnected) {
      widget.conexion!.output.add(Uint8List.fromList([micNumber]));
      await widget.conexion!.output.allSent;
      print("Micrófono $micNumber seleccionado.");
    }
  }

  void startRecording(int micNumber) async {
    changeMic(micNumber);
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/mic_$micNumber.wav';
    final file = File(filePath);

    final duration = Duration(seconds: 15);
    final endTime = DateTime.now().add(duration);

    _audioSubscription = widget.conexion!.input!.listen((Uint8List data) {
      if (DateTime.now().isBefore(endTime)) {
        writeDataToWav(data, micNumber);
        print("Escribiendo datos en mic $micNumber : $data");
      } else {
        _audioSubscription?.cancel();
        setState(() {
          isAudioReady[micNumber - 1] = true;
        });
        // Subir archivo a Firebase después de la grabación
        uploadWavToFirebase(file, micNumber);
      }
    });

    print("Grabación iniciada para micrófono $micNumber durante 15 segundos.");
  }

  void writeDataToWav(Uint8List audioData, int micNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/mic_$micNumber.wav';
    final file = File(filePath);

    // Escribir datos de audio
    await file.writeAsBytes(audioData, mode: FileMode.append);
    totalDataSize += audioData.length; // Actualizar tamaño de datos

    // Actualizar encabezado después de escribir datos
    await file.writeAsBytes(createWavHeader(totalDataSize), mode: FileMode.write);

    print("Datos escritos en $filePath, tamaño total de datos: $totalDataSize bytes");
  }

  Future<void> uploadWavToFirebase(File wavFile, int micNumber) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('Toyota/${wavFile.path.split('/').last}');
      final uploadTask = await storageRef.putFile(wavFile);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('Audios').add({
        'Marca': vehicleBrand,
        'Parte': micLabels[micNumber - 1],
        'Url': downloadUrl,
      });

      print('Datos subidos a Firestore correctamente');
    } catch (e) {
      print('Error al subir archivo a Firebase: $e');
    }
  }

  void playWavFile(int micNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/mic_$micNumber.wav';
    await audioPlayer.play(DeviceFileSource(filePath));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Marca del Vehículo',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              vehicleBrand = value;
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: micLabels.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: micLabels[index],
                        decoration: InputDecoration(
                          labelText: 'canal ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            micLabels[index] = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              startRecording(index + 1);
                            },
                            child: const Text('Grabar'),
                          ),
                          if (isAudioReady[index])
                            ElevatedButton(
                              onPressed: () {
                                playWavFile(index + 1);
                              },
                              child: const Text('Escuchar Audio'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}

// Extensión para convertir enteros a bytes
extension IntToBytes on int {
  List<int> toBytes(int byteCount) {
    List<int> bytes = [];
    for (int i = 0; i < byteCount; i++) {
      bytes.add((this >> (8 * i)) & 0xff);
    }
    return bytes;
  }
}
