import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../services/event_provider.dart';

class UserFormScreen extends StatefulWidget {
  final AppUser? user;
  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService.instance;

  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _phone = TextEditingController(text: widget.user?.phone ?? '');
  late final _address = TextEditingController(text: widget.user?.address ?? '');
  final _password = TextEditingController();
  String _role = 'KASIR';
  String _status = 'AKTIF';
  bool _saving = false;
  bool _obscure = true;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _role = widget.user!.role.isNotEmpty ? widget.user!.role.toUpperCase() : 'KASIR';
      _status = widget.user!.status.isNotEmpty ? widget.user!.status.toUpperCase() : 'AKTIF';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.call('user.save', {
        if (_isEdit) 'id': widget.user!.id,
        'email': _email.text.trim(),
        'name': _name.text.trim(),
        'password': _password.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'role': _role,
        'status': _status,
      });
      if (mounted) {
        context.read<EventProvider>().refreshUser();
        showToast(context, 'User berhasil disimpan');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit User' : 'Tambah User')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No HP (Opsional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Alamat (Opsional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: _isEdit ? 'Password (kosongkan jika tidak diubah)' : 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (!_isEdit && (v == null || v.trim().isEmpty)) return 'Password wajib diisi untuk user baru';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'KASIR', child: Text('Kasir')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'KASIR'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'AKTIF', child: Text('Aktif')),
                DropdownMenuItem(value: 'NONAKTIF', child: Text('Nonaktif')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'AKTIF'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan User'),
            ),
          ],
        ),
      ),
    );
  }
}
