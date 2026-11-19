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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: groupPhoto == null
                  ? Icon(
                      Icons.groups_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                    )
                  : ClipOval(
                      child: SizedBox.expand(
                        child: ProfilePhotoImage(
                          source: groupPhoto,
                          fallback: Icon(
                            Icons.groups_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Integrantes · ${widget.group.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, UserProfile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudieron cargar los integrantes.'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profiles = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.group.memberIds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final uid = widget.group.memberIds[index];
              final profile = profiles[uid];
              final name = profile?.name.isNotEmpty == true
                  ? profile!.name
                  : widget.group.memberNames[uid] ?? 'Usuario';
              final isCreator = uid == widget.group.createdBy;

              return Card(
                child: ListTile(
                  leading: PersonAvatar(
                    name: name,
                    photoSource: profile?.photoSource,
                    radius: 24,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isCreator ? 'Creador del grupo' : 'Integrante',
                  ),
                  trailing: isCreator
                      ? Icon(
                          Icons.star_rounded,
                          color: theme.colorScheme.primary,
                          semanticLabel: 'Creador del grupo',
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
