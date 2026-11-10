import 'package:flutter/material.dart';
import '../../models/group_model.dart';

enum GroupOptionsAction {
  members,
  inviteMember,
  history,
  chat,
  balance,
  analytics,
  reports,
  delete,
}

class GroupOptionsScreen extends StatelessWidget {
  const GroupOptionsScreen({
    super.key,
    required this.group,
    required this.canDeleteGroup,
    required this.onAction,
  });

  final GroupModel group;
  final bool canDeleteGroup;
  final ValueChanged<GroupOptionsAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final options = <_GroupOption>[
      _GroupOption(
        action: GroupOptionsAction.members,
        icon: Icons.groups_rounded,
        title: 'Integrantes',
        subtitle: 'Personas del grupo',
        colors: const [Color(0xFF3285D4), Color(0xFF55B5E5)],
      ),
      _GroupOption(
        action: GroupOptionsAction.inviteMember,
        icon: Icons.person_add_alt_1_rounded,
        title: 'Invitar',
        subtitle: 'Añadir a alguien',
        colors: const [Color(0xFF08A89D), Color(0xFF51C9B0)],
      ),
      _GroupOption(
        action: GroupOptionsAction.chat,
        icon: Icons.chat_bubble_rounded,
        title: 'Chat del grupo',
        subtitle: 'Conversar con todos',
        colors: const [Color(0xFF21AFC4), Color(0xFF62D7E5)],
      ),
      _GroupOption(
        action: GroupOptionsAction.balance,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Balance',
        subtitle: 'Saldos y liquidaciones',
        colors: const [Color(0xFF4F69D6), Color(0xFF8092EE)],
      ),
      _GroupOption(
        action: GroupOptionsAction.analytics,
        icon: Icons.insights_rounded,
        title: 'Analítica',
        subtitle: 'Resumen financiero',
        colors: const [Color(0xFF8859C8), Color(0xFFB084E2)],
      ),
      _GroupOption(
        action: GroupOptionsAction.reports,
        icon: Icons.pie_chart_rounded,
        title: 'Reportes',
        subtitle: 'Exportar y compartir',
        colors: const [Color(0xFFDF8B38), Color(0xFFF2B45F)],
      ),
      _GroupOption(
        action: GroupOptionsAction.history,
        icon: Icons.history_rounded,
        title: 'Historial',
        subtitle: 'Cambios del grupo',
        colors: const [Color(0xFF397E96), Color(0xFF69B2C4)],
      ),
      if (canDeleteGroup)
        _GroupOption(
          action: GroupOptionsAction.delete,
          icon: Icons.delete_outline_rounded,
          title: 'Eliminar grupo',
          subtitle: 'Acción permanente',
          colors: const [Color(0xFFD94E61), Color(0xFFEF8390)],
          isDestructive: true,
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Opciones del grupo'),
        backgroundColor: const Color(0xFFEAF4FB),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620 ? 3 : 2;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                      sliver: SliverToBoxAdapter(
                        child: _GroupHeader(group: group),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: columns == 2 ? 1.12 : 1.18,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final option = options[index];
                          return _GroupOptionCard(
                            option: option,
                            onTap: () {
                              Navigator.of(context).pop();
                              onAction(option.action);
                            },
                          );
                        }, childCount: options.length),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Las opciones solo afectan a este grupo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = group.memberIds.length;
    return Container(
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
            color: const Color(0xFF2457C5).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: -24,
            child: Icon(
              Icons.settings_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'integrante' : 'integrantes'} · Administra tu grupo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupOption {
  const _GroupOption({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.isDestructive = false,
  });

  final GroupOptionsAction action;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final bool isDestructive;
}

class _GroupOptionCard extends StatelessWidget {
  const _GroupOptionCard({required this.option, required this.onTap});

  final _GroupOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.colors.first.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: option.colors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: option.colors.first.withValues(alpha: 0.22),
                          blurRadius: 9,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(option.icon, color: Colors.white, size: 24),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: option.isDestructive
                              ? const Color(0xFFBD3E50)
                              : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        option.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
