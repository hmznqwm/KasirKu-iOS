import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../services/event_provider.dart';
import 'user_form_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();
  Future<List<AppUser>>? _future;
  
  late EventProvider _ev;
  int _localUserVersion = 0;

  @override
  void initState() {
    super.initState();
    _ev = context.read<EventProvider>();
    _localUserVersion = _ev.userVersion;
    _ev.addListener(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _ev.removeListener(_onEvent);
    super.dispose();
  }

  void _onEvent() {
    if (_localUserVersion != _ev.userVersion) {
      _localUserVersion = _ev.userVersion;
      if (mounted) _load(q: _searchCtrl.text);
    }
  }

  void _load({String? q}) {
    setState(() {
      _future = _api.call('user.list', {'q': q ?? ''}).then(
          (d) => (d as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList());
    });
  }

  Future<void> _delete(AppUser u) async {
    final ok = await confirmDialog(context, title: 'Hapus User', message: 'Hapus user "${u.name}"?');
    if (!ok) return;
    try {
      await _api.call('user.delete', {'id': u.id});
      if (mounted) {
        context.read<EventProvider>().refreshUser();
        showToast(context, 'User berhasil dihapus');
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen User')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const UserFormScreen()));
          if (saved == true) _load(q: _searchCtrl.text);
        },
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('User'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari email, nama, role...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
              ),
              onSubmitted: (v) => _load(q: v),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(q: _searchCtrl.text),
              child: FutureBuilder<List<AppUser>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snap.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ErrorView(message: snap.error.toString(), onRetry: () => _load(q: _searchCtrl.text)),
                    );
                  }
                  final rows = snap.data ?? [];
                  if (rows.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [EmptyState(message: 'Belum ada user', icon: Icons.people_outline)],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final u = rows[i];
                      final aktif = u.status.toUpperCase() == 'AKTIF';
                      return SectionCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(u.email, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                  if (u.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('No HP: ${u.phone}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, children: [
                                    StatusPill(text: u.role, bg: AppColors.stockLowBg, fg: AppColors.stockLowText),
                                    StatusPill(
                                      text: u.status,
                                      bg: aktif ? AppColors.stockOkBg : AppColors.stockOutBg,
                                      fg: aktif ? AppColors.stockOkText : AppColors.stockOutText,
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  final saved = await Navigator.push<bool>(
                                      context, MaterialPageRoute(builder: (_) => UserFormScreen(user: u)));
                                  if (saved == true) _load(q: _searchCtrl.text);
                                } else if (v == 'delete') {
                                  _delete(u);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
