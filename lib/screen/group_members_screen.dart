import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/user_profile_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/person_avatar.dart';
import '../widgets/profile_photo_image.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.group});

  final GroupModel group;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _firestoreService = FirestoreService();
  late Future<Map<String, UserProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  void _loadProfiles() {
    _profilesFuture = _firestoreService.getUserProfiles(widget.group.memberIds);
  }

  void _retry() {
    setState(_loadProfiles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupPhoto = widget.group.photoSource;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE7F3F8),
              child: groupPhoto == null || groupPhoto.isEmpty
                  ? const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF087F8C),
                      size: 20,
                    )
                  : ClipOval(
                      child: SizedBox.expand(
                        child: ProfilePhotoImage(
                          source: groupPhoto,
                          fallback: const Icon(
                            Icons.groups_rounded,
                            color: Color(0xFF087F8C),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEAF4FB),
        foregroundColor: const Color(0xFF173B75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: FutureBuilder<Map<String, UserProfile>>(
            future: _profilesFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _MembersStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'No se pudieron cargar los integrantes',
                  message: 'Revisa tu conexión e inténtalo nuevamente.',
                  action: FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2457C5),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2457C5)),
                );
              }

              final profiles = snapshot.data!;
              if (widget.group.memberIds.isEmpty) {
                return _MembersStateCard(
                  icon: Icons.groups_outlined,
                  title: 'Aún no hay integrantes',
                  message: 'Los miembros del grupo aparecerán en esta lista.',
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _MembersHeader(
                    groupName: widget.group.name,
                    memberCount: widget.group.memberIds.length,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F3F8),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.groups_2_rounded,
                          color: Color(0xFF087F8C),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Integrantes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF173B75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Personas que forman parte de este grupo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF687C8D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ...widget.group.memberIds.map((uid) {
                    final profile = profiles[uid];
                    final profileName = profile?.name.trim();
                    final fallbackName =
                        widget.group.memberNames[uid]?.trim() ?? '';
                    final name = profileName?.isNotEmpty == true
                        ? profileName!
                        : fallbackName.isNotEmpty
                        ? fallbackName
                        : 'Usuario';
                    final email = profile?.email.trim() ?? '';
                    final isCreator = uid == widget.group.createdBy;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemberCard(
                        name: name,
                        email: email,
                        photoSource: profile?.photoSource,
                        isCreator: isCreator,
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MembersHeader extends StatelessWidget {
  const _MembersHeader({required this.groupName, required this.memberCount});

  final String groupName;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82B8), Color(0xFF69B8D0)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B87).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -62,
            child: Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'COMUNIDAD DEL GRUPO',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.05,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                groupName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Conoce a las personas que comparten los gastos del grupo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.17),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'integrante' : 'integrantes'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.name,
    required this.email,
    required this.photoSource,
    required this.isCreator,
  });

  final String name;
  final String email;
  final String? photoSource;
  final bool isCreator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: isCreator
              ? const Color(0xFF54A6C7).withValues(alpha: 0.42)
              : const Color(0xFFDCE8EF),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCreator
                      ? const Color(0xFF54A6C7).withValues(alpha: 0.55)
                      : const Color(0xFFE7F3F8),
                  width: 2,
                ),
              ),
              child: PersonAvatar(
                name: name,
                photoSource: photoSource,
                radius: 23,
                backgroundColor: const Color(0xFFE7F3F8),
                foregroundColor: const Color(0xFF087F8C),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCreator ? 'Creador del grupo' : 'Integrante',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCreator
                          ? const Color(0xFF087F8C)
                          : const Color(0xFF687C8D),
                      fontWeight: isCreator
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF8093A1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isCreator)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F3F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Tooltip(
                  message: 'Creador del grupo',
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFF2457C5),
                    size: 20,
                  ),
                ),
              )
            else
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFFB2C4CF),
                size: 19,
              ),
          ],
        ),
      ),
    );
  }
}

class _MembersStateCard extends StatelessWidget {
  const _MembersStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 1,
            shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFFDCE8EF)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F8),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(icon, size: 29, color: const Color(0xFF087F8C)),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF687C8D),
                      height: 1.4,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 17), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
