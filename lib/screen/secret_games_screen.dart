import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SecretGamesScreen extends StatelessWidget {
  const SecretGamesScreen({super.key});

  static const _games = <_WebGame>[
    _WebGame(
      name: '2048',
      description: 'Combina los números y llega hasta 2048.',
      url: 'https://play2048.co/',
      icon: Icons.grid_view_rounded,
      colors: [Color(0xFF6754C8), Color(0xFF9585EB)],
    ),
    _WebGame(
      name: 'Chrome Dino',
      description: 'Salta cactus y aguanta todo lo que puedas.',
      url: 'https://chromedino.com/',
      icon: Icons.directions_run_rounded,
      colors: [Color(0xFF087F8C), Color(0xFF45B8A7)],
    ),
    _WebGame(
      name: 'Hextris',
      description: 'Encaja los bloques en este puzzle de reflejos.',
      url: 'https://hextris.io/',
      icon: Icons.hexagon_rounded,
      colors: [Color(0xFFDF8B38), Color(0xFFF2B45F)],
    ),
  ];

  Future<void> _openGame(BuildContext context, _WebGame game) async {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final mode = isMobile
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication;

    try {
      final opened = await launchUrl(Uri.parse(game.url), mode: mode);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir ${game.name}.')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${game.name}: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Arcade secreto'),
        backgroundColor: const Color(0xFFEAF4FB),
        foregroundColor: const Color(0xFF173B75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2457C5), Color(0xFF087F8C)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2457C5).withValues(alpha: 0.2),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.sports_esports_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Una pausa rápida',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Juegos web ligeros para despejarte un rato.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Elige un juego',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 620 ? 3 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _games.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 194,
                    ),
                    itemBuilder: (context, index) {
                      final game = _games[index];
                      return _GameCard(
                        game: game,
                        onTap: () => _openGame(context, game),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Los juegos se abren desde sus sitios web originales.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});

  final _WebGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCE8EF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173B75).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: game.colors),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(game.icon, color: Colors.white, size: 25),
              ),
              const Spacer(),
              Text(
                game.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                game.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Jugar',
                    style: TextStyle(
                      color: Color(0xFF2457C5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: Color(0xFF2457C5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebGame {
  const _WebGame({
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
    required this.colors,
  });

  final String name;
  final String description;
  final String url;
  final IconData icon;
  final List<Color> colors;
}
