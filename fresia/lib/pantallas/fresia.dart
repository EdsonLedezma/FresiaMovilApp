import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class Fresia extends StatefulWidget {
  const Fresia({super.key});

  @override
  State<Fresia> createState() => _FresiaState();
}

class _FresiaState extends State<Fresia> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> _prompts = [
    '¿Cómo se comporta un auto con problemas de válvulas?',
    '¿Cómo saber si un auto tiene las rótulas dañadas?',
    '¿Qué hacer si mi vehículo se sobrecalienta?',
    'Recomiéndame autos con buen consumo de combustible para ciudad',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendData(String message) async {
    const apiKey = "AIzaSyDtvSKbMz8IiNiu6rMN5wBX0xk_RRfn4C8";

    final model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 64,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'text/plain',
      ),
      systemInstruction: Content.system(
        'Responde con un lenguaje formal, educado y vuélvete un experto mecánico automotriz',
      ),
    );

    final chat = model.startChat(history: [
      Content.multi([
        TextPart(message),
      ]),
    ]);

    final content = Content.text(message);
    final response = await chat.sendMessage(content);

    setState(() {
      _response = response.text!;
    });
  }

  int _selectedIndex = 2;

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
        title: const Text('Fresia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ScaleTransition(
              scale: _animation,
              child: const Text(
                'Resuelve tus dudas con el asistente virtual de Fresia',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Escriba aquí su pregunta...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, // Espaciado entre los botones
              runSpacing: 12, // Espaciado vertical entre los botones
              children: _prompts.map((prompt) {
                return ElevatedButton(
                  onPressed: () {
                    _sendData(prompt);
                  },
                  child: Text(prompt),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _sendData(_controller.text);
              },
              child: const Text('Enviar'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _response,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ),
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
}
