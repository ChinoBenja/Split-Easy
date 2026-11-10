import 'package:flutter/material.dart';
import 'profile_photo_image.dart';

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.onHomeTap,
    required this.onGroupsTap,
    required this.onAssistantTap,
    required this.onCreateGroupTap,
    required this.onAddExpenseTap,
    required this.onProfileTap,
    required this.profilePhotoFuture,
  });

  final VoidCallback onHomeTap;
  final VoidCallback? onGroupsTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onCreateGroupTap;
  final VoidCallback onAddExpenseTap;
  final VoidCallback onProfileTap;
  final Future<String?> profilePhotoFuture;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF12345B), Color(0xFF075A78)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    onTap: onHomeTap,
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.groups_rounded,
                    label: 'Grupos',
                    onTap: onGroupsTap,
                    selected: onGroupsTap == null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CenterActionButton(
                          tooltip: 'Crear grupo',
                          icon: Icons.group_add_rounded,
                          onTap: onCreateGroupTap,
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        _CenterActionButton(
                          tooltip: 'Agregar gasto',
                          icon: Icons.attach_money_rounded,
                          onTap: onAddExpenseTap,
                          showPlus: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Asistente',
                    onTap: onAssistantTap,
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    label: 'Perfil',
                    onTap: onProfileTap,
                    iconWidget: FutureBuilder<String?>(
                      future: profilePhotoFuture,
                      builder: (context, snapshot) {
                        final photoSource = snapshot.data;
                        const fallback = Icon(
                          Icons.person_outline_rounded,
                          size: 21,
                          color: Color(0xFF173B75),
                        );
                        return CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.white,
                          child: photoSource == null || photoSource.isEmpty
                              ? fallback
                              : ClipOval(
                                  child: SizedBox.expand(
                                    child: ProfilePhotoImage(
                                      source: photoSource,
                                      fallback: fallback,
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ??
                Icon(
                  icon,
                  size: 23,
                  color: selected
                      ? const Color(0xFFB4F0FF)
                      : Colors.white.withValues(alpha: 0.9),
                ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? const Color(0xFFB4F0FF)
                    : Colors.white.withValues(alpha: 0.9),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showPlus = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showPlus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 25, color: const Color(0xFFB4F0FF)),
                if (showPlus)
                  Positioned(
                    right: 6,
                    top: 5,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB4F0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 12,
                        color: Color(0xFF12345B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
