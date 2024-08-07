import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  final int sampleRate = 44100;
  final int bitsPerSample = 16;
  final int numChannels = 1;

  late File tempFile;

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
    createTempWavFile(); // Crear archivo .wav al iniciar
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

  Future<void> createTempWavFile() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    tempFile = File('${appDir.path}/temp_audio.wav');
    await tempFile.create();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listo para grabar')),
    );
  }

  void listenForAudio() {
    if (widget.conexion != null && widget.conexion!.isConnected) {
      audioStreamSubscription = widget.conexion!.input!.listen(
            (Uint8List data) {
          if (data.isNotEmpty) {
            if (isRecording) {
              writeToTempFile(data);
            }
          }
        },
        onError: (error) {
          print('Error al recibir audio: $error');
        },
        onDone: () {
          // Manejo de desconexión
          print('La conexión se ha cerrado');
          setState(() {
            isRecording = false; // Detener la grabación si se cierra la conexión
          });
        },
      );
    }
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
    if (!isRecording) {
      setState(() {
        isRecording = true;
        isAudioReady = false;
      });

      // Grabar durante 10 segundos
      await Future.delayed(const Duration(seconds: 10));

      setState(() {
        isRecording = false;
        isAudioReady = true;
      });

      // Escribir el archivo WAV
      await writeWavFile(tempFile.readAsBytesSync(), micNumber);
      await tempFile.delete(); // Opcional: Eliminar archivo temporal
      await createTempWavFile(); // Crear un nuevo archivo temporal
    }
  }

  Future<void> writeWavFile(Uint8List audioData, int micNumber) async {
    int dataSize = audioData.length;
    int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    Uint8List header = createWavHeader(sampleRate, byteRate, bitsPerSample, dataSize);

    Directory appDir = await getApplicationDocumentsDirectory();
    File wavFile = File('${appDir.path}/mic_${micNumber}_audio.wav');
    wavFiles[micNumber - 1] = wavFile;

    // Escribir los datos de audio y el encabezado en el archivo
    await wavFile.writeAsBytes([...header, ...audioData]);
    print('Archivo WAV creado en: ${wavFile.path}');
  }

  Uint8List createWavHeader(int sampleRate, int bitsPerSample, int numChannels, int dataSize) {
    List<int> header = [];

    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll((36 + dataSize).toBytes(4)); // Chunk size
    header.addAll('WAVE'.codeUnits);

    // fmt subchunk
    header.addAll('fmt '.codeUnits);
    header.addAll((16).toBytes(4)); // Subchunk size
    header.addAll((1).toBytes(2)); // Audio format (PCM)
    header.addAll((1).toBytes(2)); // Number of channels (mono)
    header.addAll((sampleRate).toBytes(4)); // Sample rate
    header.addAll(((sampleRate * 1 * 16) ~/ 8).toBytes(4)); // Byte rate
    header.addAll(((1 * 16) ~/ 8).toBytes(2)); // Block align
    header.addAll((16).toBytes(2)); // Bits per sample

    // data subchunk
    header.addAll('data'.codeUnits);
    header.addAll(dataSize.toBytes(4)); // Data size

    return Uint8List.fromList(header);
  }

  Future<void> playAudio(File wavFile) async {
    await audioPlayer.play(DeviceFileSource(wavFile.path));
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                                if (!isRecording) {
                                  startRecording(index + 1);
                                }
                              },
                              child: const Text('Grabar'),
                            ),
                          ]
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
