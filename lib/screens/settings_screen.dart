import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/app_store.dart';
import '../widgets/app_widgets.dart';
import '../services/sim_sms_service.dart';
import 'pricing_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _username;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _smsSaving = false;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.store.auth.username);
  }

  @override
  void dispose() {
    _username.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _changeAutomaticSms({required bool enabled, int? minutes}) async {
    if (_smsSaving) return;
    final newMinutes = minutes ?? widget.store.smsMinutes;
    final verified = await askYesNo(
      context,
      title: enabled ? 'Enable automatic SIM SMS?' : 'Disable automatic SIM SMS?',
      message: enabled
          ? 'The shop phone will send ONE pickup reminder per eligible order '
            'around ${TimeOfDay(hour: newMinutes ~/ 60, minute: newMinutes % 60).format(context)} '
            'on the claim date. SMS credits may be charged. Confirm customer '
            'consent, test the SIM first, and leave the phone powered on. '
            'Today’s past-due send times and earlier dates are not bulk-sent.'
          : 'Cancel all future SMS reminders? Messages already sent cannot be cancelled.',
      yesText: enabled ? 'Yes, enable' : 'Yes, disable',
    );
    if (!verified || !mounted) return;
    setState(() => _smsSaving = true);
    try {
      if (enabled) {
        final supported = await SimSmsService.isSmsCapable();
        if (!supported) throw StateError('This Android device cannot send SIM SMS.');
        final allowed = await SimSmsService.requestPermission();
        if (!allowed) throw StateError('SMS permission denied.');
      }
      final count = await widget.store.updateAutoSms(
        enabled: enabled, minutes: newMinutes,
      );
      if (mounted) showAppMessage(context, enabled
          ? 'Automation enabled. $count reminders scheduled.'
          : 'Automatic SMS disabled. Future reminders cancelled.');
    } catch (error) {
      if (mounted) showAppMessage(context, 'SMS settings not updated: $error', error: true);
    } finally {
      if (mounted) setState(() => _smsSaving = false);
    }
  }

  Future<void> _pickSmsTime() async {
    final minutes = widget.store.smsMinutes;
    final result = await showTimePicker(context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    if (result == null || !mounted) return;
    final newMinutes = result.hour * 60 + result.minute;
    if (widget.store.autoSmsEnabled) {
      await _changeAutomaticSms(enabled: true, minutes: newMinutes);
    } else {
      await widget.store.settingsBox.put('autoSmsMinutes', newMinutes);
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveCredentials() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_form.currentState!.validate()) return;
    final confirmed = await askYesNo(
      context,
      title: 'Update login details?',
      message: 'Are you sure you want to save the new administrator credentials? '
          'Use the new username/password when you sign in next time.',
      yesText: 'Yes, update',
      noText: 'No, edit',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final success = await widget.store.auth.changeCredentials(
        currentPassword: _currentPassword.text,
        newUsername: _username.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      if (!success) {
        showAppMessage(context, 'Current password is incorrect.', error: true);
        return;
      }
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      showAppMessage(context, 'Login details updated.');
      setState(() {});
    } catch (error) {
      if (mounted) showAppMessage(context, 'Update failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 22, compact ? 16 : 28, 34),
            children: [
              const PageHeading(
                title: 'Shop settings',
                subtitle: 'Manage laundry rates and administrator login.'),
              const SizedBox(height: 19),
              SurfaceCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightTeal,
                    child: Icon(Icons.payments_outlined, color: AppColors.teal)),
                  title: const Text('Laundry pricing',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Random, White, Blanket • Price per kg'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => PricingScreen(store: widget.store))),
                ),
              ),
              const SizedBox(height: 18),
              SurfaceCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.sms_outlined, color: AppColors.teal),
                    SizedBox(width: 10),
                    Expanded(child: Text('Automatic SMS reminders',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                        color: AppColors.navy))),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Send one SMS automatically on the claim day using '
                      'the phone’s default SMS SIM. Test the SIM first in the SMS tab.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.store.autoSmsEnabled
                        ? 'Automatic SMS is ON' : 'Automatic SMS is OFF'),
                    subtitle: const Text('Requires an active SIM, SMS permission '
                        'and customer consent.'),
                    value: widget.store.autoSmsEnabled,
                    onChanged: _smsSaving ? null : (value) =>
                        _changeAutomaticSms(enabled: value),
                  ),
                  const Divider(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule, color: AppColors.teal),
                    title: const Text('Claim-day send time'),
                    subtitle: Text(TimeOfDay(
                      hour: widget.store.smsMinutes ~/ 60,
                      minute: widget.store.smsMinutes % 60,
                    ).format(context)),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _smsSaving ? null : _pickSmsTime,
                  ),
                  const Text('Android schedules these as background tasks, not '
                      'exact-time alarms. If the phone is off, force-stopped or has '
                      'no SIM signal, messages may be delayed or fail.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  if (widget.store.smsSchedulingError != null) ...[
                    const SizedBox(height: 10),
                    Text('Scheduling error: ${widget.store.smsSchedulingError}',
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ],
              )),
              const SizedBox(height: 18),
              SurfaceCard(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.admin_panel_settings_outlined, color: AppColors.teal),
                        SizedBox(width: 10),
                        Text('Administrator login', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.navy)),
                      ]),
                      const SizedBox(height: 9),
                      const Text('Verify your current password before making changes.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          return text.length < 3 || text.length > 30
                              ? 'Username must be 3–30 characters.' : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currentPassword,
                        obscureText: !_showCurrent,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: 'Show or hide current password',
                            icon: Icon(_showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showCurrent = !_showCurrent),
                          )),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Current password is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: !_showNew,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'New password (optional)',
                          helperText: 'Leave blank to keep the old password.',
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Show or hide new password',
                            icon: Icon(_showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showNew = !_showNew),
                          )),
                        validator: (value) => value != null && value.isNotEmpty && value.length < 8
                            ? 'Use at least 8 characters.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: !_showNew,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.verified_user_outlined)),
                        validator: (value) => value != _newPassword.text
                            ? 'New passwords do not match.' : null,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _saveCredentials,
                          icon: _saving
                              ? const SizedBox(height: 16, width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Review & save login details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Credentials are stored as a salted password hash in Hive. '
                  'This is a local login gate, not encrypted storage or a cloud account.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
