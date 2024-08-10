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
import '../firebase_options.dart';

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

  final AudioPlayer audioPlayer = AudioPlayer();
  late StreamSubscription<Uint8List> audioStreamSubscription;
  List<File?> wavFiles = [null, null, null, null];
  bool isRecording = false;
  bool isAudioReady = false;
  bool isPrepared = false; // Para saber si está preparado para grabar

  final int sampleRate = 44100;
  final int bitsPerSample = 16;
  final int numChannels = 1;

  late File tempFile;
  String vehicleBrand = ""; // Variable para almacenar la marca del vehículo

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
    listenForAudio();
  }

  Future<void> requestStoragePermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      listenForAudio();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos de almacenamiento denegados')),
      );
    }
  }

  void listenForAudio() {
    if (widget.conexion != null && widget.conexion!.isConnected) {
      audioStreamSubscription = widget.conexion!.input!.listen(
            (Uint8List data) {
          if (data.isNotEmpty && isRecording) {
            writeToTempFile(data);
          }
        },
        onError: (error) {
          print('Error al recibir audio: $error');
        },
        onDone: () {
          print('La conexión se ha cerrado');
          setState(() {
            isRecording = false;
          });
        },
      );
    }
  }

  Future<void> createTempWavFile() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    tempFile = File('${appDir.path}/temp_audio.wav');
    await tempFile.create();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listo para grabar')),
    );
  }

  Future<void> writeToTempFile(Uint8List data) async {
    try {
      await tempFile.writeAsBytes(data, mode: FileMode.append);
      print("Escribiendo: $data");
    } catch (e) {
      print('Error al escribir en el archivo: $e');
    }
  }

  void sendData(int data) async {
    try {
      if (widget.conexion != null && widget.conexion!.isConnected) {
        widget.conexion!.output.add(Uint8List.fromList([data]));
        await widget.conexion!.output.allSent;
        print("Data sent: $data");
      } else {
        print("No está conectado");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void changeMic(int micNumber) {
    if (micNumber >= 1 && micNumber <= 4) {
      sendData(micNumber);
    } else {
      print("Número de micrófono inválido");
    }
  }

  Future<void> startRecording(int micNumber) async {
    if (isPrepared && !isRecording) {
      setState(() {
        isRecording = true;
        isAudioReady = false;
      });

      // Grabar por 10 segundos
      await Future.delayed(const Duration(seconds: 10));

      setState(() {
        isRecording = false;
        isAudioReady = true;
      });

      // Esperar un segundo para asegurarte que todos los datos se escriban
      await Future.delayed(const Duration(seconds: 1));

      // Escribir archivo WAV
      await writeWavFile(tempFile.readAsBytesSync(), micNumber);
      await tempFile.delete();
      await createTempWavFile();
    }
  }

  Future<void> prepareRecording() async {
    await createTempWavFile();
    setState(() {
      isPrepared = true; // Marca como preparado
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparado para grabar')),
    );
  }

  Future<void> writeWavFile(Uint8List audioData, int micNumber) async {
    int dataSize = audioData.length;
    int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    Uint8List header = createWavHeader(sampleRate, byteRate, bitsPerSample, dataSize);

    Directory appDir = await getApplicationDocumentsDirectory();
    File wavFile = File('${appDir.path}/mic_${micNumber}_audio.wav');
    wavFiles[micNumber - 1] = wavFile;

    await wavFile.writeAsBytes([...header, ...audioData]);
    print('Archivo WAV creado en: ${wavFile.path}');

    // Subir archivo a Firebase Storage y guardar datos en Firestore
    await uploadWavToFirebase(wavFile, micNumber);
  }

  Uint8List createWavHeader(int sampleRate, int byteRate, int bitsPerSample, int dataSize) {
    List<int> header = [];

    header.addAll('RIFF'.codeUnits);
    header.addAll((36 + dataSize).toBytes(4));
    header.addAll('WAVE'.codeUnits);

    header.addAll('fmt '.codeUnits);
    header.addAll((16).toBytes(4));
    header.addAll((1).toBytes(2));
    header.addAll((numChannels).toBytes(2));
    header.addAll((sampleRate).toBytes(4));
    header.addAll((byteRate).toBytes(4));
    header.addAll(((numChannels * bitsPerSample) ~/ 8).toBytes(2));
    header.addAll((bitsPerSample).toBytes(2));

    header.addAll('data'.codeUnits);
    header.addAll(dataSize.toBytes(4));

    return Uint8List.fromList(header);
  }

  Future<void> uploadWavToFirebase(File wavFile, int micNumber) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('audios/${wavFile.path.split('/').last}');
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

  void playAudio(File wavFile) async {
    await audioPlayer.setSourceUrl(wavFile.path);
    await audioPlayer.resume();
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
        ElevatedButton(
          onPressed: () {
            prepareRecording(); // Preparar la grabación
          },
          child: const Text('Preparar'),
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
                              changeMic(index + 1);
                            },
                            child: const Text('Cambiar Micrófono'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (isPrepared) {
                                startRecording(index + 1);
                              }
                            },
                            child: const Text('Grabar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      if (isAudioReady && wavFiles[index] != null)
                        ElevatedButton(
                          onPressed: () {
                            playAudio(wavFiles[index]!);
                          },
                          child: const Text('Escuchar Audio'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: () {
            requestStoragePermission();
          },
          child: const Text('Solicitar permisos de almacenamiento'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    audioStreamSubscription.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}

extension on int {
  List<int> toBytes(int size) {
    List<int> bytes = [];
    for (int i = 0; i < size; i++) {
      bytes.add((this >> (8 * i)) & 0xFF);
    }
    return bytes;
  }
}
