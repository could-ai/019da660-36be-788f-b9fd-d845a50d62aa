import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';

void main() {
  runApp(const Outpost99App());
}

class Outpost99App extends StatelessWidget {
  const Outpost99App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Outpost 99',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;
  
  // Estado do Jogo
  Offset playerPos = const Offset(50, 50); 
  Offset targetPos = const Offset(50, 50);
  bool isMoving = false;
  
  // Constantes do Jogo
  final double mapSize = 2000.0;
  final double speed = 180.0; // velocidade do jogador
  final double rescueTime = 90.0; // Tempo para vencer (segundos)
  
  // Gerador Central
  Offset generatorPos = const Offset(0, 0);
  double generatorFuel = 100.0; // 0 a 100%
  final double fuelDrainRate = 1.8; // perde 1.8% por segundo
  
  // Jogador
  int carriedFuel = 0;
  double timeSurvived = 0.0;
  
  // Entidades no mapa
  List<Offset> fuelDrops = [];
  final Random random = Random();
  
  // Condições de Fim de Jogo
  bool gameOver = false;
  bool won = false;
  String endMessage = "";

  @override
  void initState() {
    super.initState();
    _startNewGame();
    _ticker = createTicker(_onTick)..start();
  }
  
  void _startNewGame() {
    playerPos = const Offset(100, 100);
    targetPos = playerPos;
    isMoving = false;
    generatorPos = const Offset(0, 0);
    generatorFuel = 100.0;
    carriedFuel = 0;
    timeSurvived = 0.0;
    gameOver = false;
    won = false;
    endMessage = "";
    
    fuelDrops.clear();
    for(int i = 0; i < 40; i++) {
      _spawnFuelDrop();
    }
  }
  
  void _spawnFuelDrop() {
    double x = (random.nextDouble() * mapSize) - (mapSize / 2);
    double y = (random.nextDouble() * mapSize) - (mapSize / 2);
    // Evitar nascer muito perto do gerador
    if (Offset(x, y).distance > 150) {
      fuelDrops.add(Offset(x, y));
    } else {
      _spawnFuelDrop();
    }
  }

  void _onTick(Duration elapsed) {
    if (gameOver || won) return;
    
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    
    double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;
    
    setState(() {
      _updateGame(dt);
    });
  }
  
  void _updateGame(double dt) {
    // Atualizar Tempo
    timeSurvived += dt;
    if (timeSurvived >= rescueTime) {
      won = true;
      endMessage = "O RESGATE CHEGOU!\nVocê sobreviveu à escuridão.";
      return;
    }
    
    // Atualizar Bateria do Gerador
    generatorFuel -= fuelDrainRate * dt;
    if (generatorFuel <= 0) {
      generatorFuel = 0;
      gameOver = true;
      endMessage = "O GERADOR DESLIGOU.\nA Mãe Alien te encontrou nas sombras...";
      return;
    }
    
    // Mover Jogador
    if (isMoving) {
      double distance = (targetPos - playerPos).distance;
      if (distance < speed * dt) {
        playerPos = targetPos;
        isMoving = false;
      } else {
        Offset direction = (targetPos - playerPos) / distance;
        playerPos += direction * speed * dt;
      }
    }
    
    // Coleta de Células de Energia
    List<Offset> collected = [];
    for (var drop in fuelDrops) {
      if ((drop - playerPos).distance < 40) { // Raio de coleta
        collected.add(drop);
        carriedFuel += 1;
      }
    }
    fuelDrops.removeWhere((drop) => collected.contains(drop));
    
    // Recarregar Gerador
    if ((generatorPos - playerPos).distance < 80) {
      if (carriedFuel > 0) {
        generatorFuel += carriedFuel * 20.0; // Cada célula recupera 20%
        if (generatorFuel > 100.0) generatorFuel = 100.0;
        carriedFuel = 0;
      }
    }
  }

  void _handleInput(Offset localPosition, Size screenSize) {
    if (gameOver || won) return;
    // Traduz o toque na tela para o mundo, baseado no centro da tela (que é a câmera do jogador)
    Offset screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    Offset delta = localPosition - screenCenter;
    targetPos = playerPos + delta;
    isMoving = true;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Área de Jogo (Renderização)
          GestureDetector(
            onPanDown: (details) => _handleInput(details.localPosition, screenSize),
            onPanUpdate: (details) => _handleInput(details.localPosition, screenSize),
            child: CustomPaint(
              size: Size.infinite,
              painter: GameWorldPainter(
                playerPos: playerPos,
                generatorPos: generatorPos,
                fuelDrops: fuelDrops,
                generatorFuel: generatorFuel,
              ),
            ),
          ),
          
          // Efeito de Escuridão
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center, // Focado no jogador (centro da tela)
                  radius: 0.5 + (generatorFuel / 100.0) * 0.8, // Luz diminui com o gerador
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(1.0 - (generatorFuel / 100.0) * 0.5),
                    Colors.black
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // UI - Interface
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildUIBox(
                  "Resgate em:", 
                  "${(rescueTime - timeSurvived).toInt()}s",
                  Colors.white
                ),
                _buildUIBox(
                  "Energia (Gerador):", 
                  "${generatorFuel.toInt()}%",
                  generatorFuel > 30 ? Colors.cyan : Colors.redAccent
                ),
                _buildUIBox(
                  "Células na Mochila:", 
                  "$carriedFuel",
                  Colors.amber
                ),
              ],
            ),
          ),

          // Tela de Fim de Jogo ou Vitória
          if (gameOver || won)
            Container(
              color: gameOver ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      endMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      onPressed: () {
                        setState(() {
                          _lastTime = Duration.zero;
                          _startNewGame();
                        });
                      },
                      child: const Text("JOGAR NOVAMENTE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildUIBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class GameWorldPainter extends CustomPainter {
  final Offset playerPos;
  final Offset generatorPos;
  final List<Offset> fuelDrops;
  final double generatorFuel;

  GameWorldPainter({
    required this.playerPos,
    required this.generatorPos,
    required this.fuelDrops,
    required this.generatorFuel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Salva o estado para a câmera
    canvas.save();
    
    // Centraliza a câmera no jogador
    canvas.translate(size.width / 2 - playerPos.dx, size.height / 2 - playerPos.dy);

    // Fundo do mapa - Chão lunar (pontos simples)
    final Paint floorPaint = Paint()..color = Colors.white10;
    for (int i = -1000; i < 1000; i += 100) {
      for (int j = -1000; j < 1000; j += 100) {
        canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 2, floorPaint);
      }
    }

    // Desenhar Gerador
    final Paint generatorBase = Paint()..color = Colors.blueGrey.shade800;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: generatorPos, width: 100, height: 100), 
        const Radius.circular(10)
      ), 
      generatorBase
    );
    
    // Luz do Gerador piscando com base na energia
    final Paint generatorGlow = Paint()
      ..color = generatorFuel > 30 ? Colors.cyan.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(generatorPos, 20 + (generatorFuel / 5), generatorGlow);

    // Desenhar Células de Energia (Baterias)
    final Paint fuelPaint = Paint()..color = Colors.amber;
    for (var drop in fuelDrops) {
      canvas.drawRect(Rect.fromCenter(center: drop, width: 16, height: 16), fuelPaint);
      canvas.drawRect(
        Rect.fromCenter(center: drop - const Offset(0, 8), width: 8, height: 4), 
        Paint()..color = Colors.white54
      );
    }

    // Desenhar Jogador (Astronauta visto de cima)
    final Paint playerSuit = Paint()..color = Colors.white;
    final Paint playerVisor = Paint()..color = Colors.lightBlueAccent;
    
    canvas.drawCircle(playerPos, 20, playerSuit); // Corpo
    canvas.drawOval(
      Rect.fromCenter(center: playerPos + const Offset(0, 5), width: 24, height: 12), 
      playerVisor
    ); // Visor do capacete

    // Restaura o canvas
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GameWorldPainter oldDelegate) {
    return true; // Para animação 60fps
  }
}
