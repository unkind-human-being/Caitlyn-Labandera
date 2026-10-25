import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_theme.dart';
import '../core/display_format.dart';
import '../data/app_store.dart';
import '../data/laundry_order.dart';
import '../services/sim_sms_service.dart';
import '../widgets/app_widgets.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> with WidgetsBindingObserver {
  static const _pageSize = 10;
  final _testPhone = TextEditingController();
  final _testMessage = TextEditingController(
    text: 'Caitlyn Laundry Shop: This is a test SMS from our shop phone.',
  );
  Timer? _poller;
  bool _smsCapable = false;
  bool _hasPermission = false;
  bool _testing = false;
  bool _refreshing = false;
  String? _testRequestId;
  List<Map<String, dynamic>> _nativeStatuses = [];
  String? _busyOrder;
  String _filter = 'Due & overdue';
  String _search = '';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _testPhone.dispose();
    _testMessage.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait([
        SimSmsService.isSmsCapable(),
        SimSmsService.hasPermission(),
      ]);
      final statuses = await SimSmsService.statuses();
      await widget.store.refreshNativeSms();
      if (mounted) setState(() {
        _smsCapable = results[0];
        _hasPermission = results[1];
        _nativeStatuses = statuses;
      });
    } catch (_) {
      if (mounted) setState(() {
        _smsCapable = false;
        _hasPermission = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _requestPermission() async {
    try {
      if (!_smsCapable) {
        showAppMessage(context, 'This device has no SMS-capable SIM hardware.', error: true);
        return;
      }
      final granted = await SimSmsService.requestPermission();
      await _refresh();
      if (mounted) showAppMessage(context, granted
          ? 'SMS permission granted. You can send a test.'
          : 'SMS permission denied. Allow SMS in Android App Settings.', error: !granted);
    } catch (error) {
      if (mounted) showAppMessage(context, 'Permission error: $error', error: true);
    }
  }

  Future<void> _sendTest() async {
    if (_testing || !_hasPermission) return;
    if (!SimSmsService.validPhMobile(_testPhone.text)) {
      showAppMessage(context, 'Enter a valid Philippine mobile number (09... or +639...).', error: true);
      return;
    }
    final message = _testMessage.text.trim();
    if (message.isEmpty || message.length > 300) {
      showAppMessage(context, 'Enter a test message of 1–300 characters.', error: true);
      return;
    }
    final proceed = await askYesNo(context,
      title: 'Send real test SMS?',
      message: 'Send to ${_testPhone.text.trim()} using the phone\'s DEFAULT '
          'SMS SIM? Carrier charges may apply. This sends immediately without '
          'opening the SMS application.',
      yesText: 'Yes, send test',
    );
    if (!proceed || !mounted) return;
    setState(() => _testing = true);
    try {
      final requestId = await SimSmsService.sendTest(
        number: _testPhone.text, message: message,
      );
      if (!mounted) return;
      setState(() => _testRequestId = requestId);
      showAppMessage(context, 'SMS requested. Check the status below and the receiving phone.');
      await _refresh();
    } catch (error) {
      if (mounted) showAppMessage(context, 'Test SMS failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _sendNow(LaundryOrder order) async {
    if (_busyOrder != null) return;
    if (!SimSmsService.validPhMobile(order.phoneNumber)) {
      showAppMessage(context, 'This customer has an invalid mobile number.', error: true);
      return;
    }
    if (!_hasPermission) {
      await _requestPermission();
      return;
    }
    if (order.claimed) {
      showAppMessage(context, 'Laundry is already marked claimed.', error: true);
      return;
    }
    if (!order.smsOptIn) {
      showAppMessage(context, 'Confirm customer consent first.', error: true);
      return;
    }
    final previous = widget.store.reminderFor(order.id);
    if (previous?.wasSent == true) {
      showAppMessage(context, 'Already marked sent. Duplicate reminders are blocked.', error: true);
      return;
    }
    final message = SimSmsService.pickupMessage(order);
    final agree = await askYesNo(context,
      title: 'Send pickup SMS now?',
      message: 'Send to ${order.fullName} (${order.phoneNumber}) directly from '
          'the default SIM?\n\n$message\n\nThis may use paid SMS credits.',
      yesText: 'Yes, send now',
    );
    if (!agree || !mounted) return;
    setState(() => _busyOrder = order.id);
    try {
      await SimSmsService.sendOrderNow(order: order, message: message);
      await widget.store.refreshNativeSms();
      if (mounted) showAppMessage(context,
          'Sending requested. Wait for network status; not yet confirmed delivered.');
    } catch (error) {
      if (mounted) showAppMessage(context, 'Could not send SMS: $error', error: true);
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  Future<void> _recordConsent(LaundryOrder order) async {
    final approved = await askYesNo(context,
      title: 'Confirm SMS permission from customer?',
      message: 'Has ${order.fullName} explicitly agreed to receive '
          'laundry pickup reminders at ${order.phoneNumber}? '
          'Only confirm if permission was actually given.',
      yesText: 'Yes, consent given',
    );
    if (!approved || !mounted) return;
    try {
      await widget.store.saveOrder(order.copyWith(smsOptIn: true));
      if (mounted) showAppMessage(context, 'Customer SMS consent recorded.');
    } catch (error) {
      if (mounted) showAppMessage(context, 'Could not save consent: $error', error: true);
    }
  }

  Future<void> _setClaimed(LaundryOrder order, bool claimed) async {
    final yes = await askYesNo(context,
      title: claimed ? 'Mark laundry claimed?' : 'Undo claimed status?',
      message: claimed
        ? 'Confirm that ${order.fullName} already received the laundry. '
          'This will cancel future automatic SMS reminders for this order.'
        : 'Are you sure this laundry order is still awaiting pickup? '
          'If SMS automation is enabled, a future reminder may be scheduled.',
      yesText: claimed ? 'Yes, claimed' : 'Yes, undo',
    );
    if (!yes || !mounted) return;
    try {
      await widget.store.saveOrder(order.copyWith(claimed: claimed));
      if (mounted) showAppMessage(context, claimed
          ? 'Laundry marked claimed. Future reminders cancelled.'
          : 'Laundry restored to unclaimed.');
    } catch (error) {
      if (mounted) showAppMessage(context, 'Could not update pickup status: $error', error: true);
    }
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _dateStatus(LaundryOrder order, DateTime today) {
    final due = _dateOnly(order.claimDate);
    if (due.isBefore(today)) return 'Overdue';
    if (due.isAtSameMomentAs(today)) return 'Due today';
    return 'Upcoming';
  }

  List<LaundryOrder> _select(List<LaundryOrder> orders) {
    final today = _dateOnly(DateTime.now());
    return orders.where((o) {
      final status = _dateStatus(o, today);
      final sms = widget.store.reminderFor(o.id);
      if (!o.fullName.toLowerCase().contains(_search.toLowerCase()) &&
          !o.phoneNumber.contains(_search) &&
          !o.receiptId.toLowerCase().contains(_search.toLowerCase())) return false;
      switch (_filter) {
        case 'Due & overdue': return !o.claimed && status != 'Upcoming' && sms?.wasSent != true;
        case 'Due today': return !o.claimed && status == 'Due today';
        case 'Overdue': return !o.claimed && status == 'Overdue';
        case 'Sent': return sms?.wasSent == true;
        case 'Failed': return sms?.nativeStatus == 'failed';
        case 'Claimed': return o.claimed;
        default: return true;
      }
    }).toList()..sort((a, b) => a.claimDate.compareTo(b.claimDate));
  }

  Map<String, dynamic>? _testStatus() {
    for (final status in _nativeStatuses.reversed) {
      if (status['id'] == _testRequestId) return status;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.store.ordersBox.listenable(),
      widget.store.remindersBox.listenable(),
      widget.store.settingsBox.listenable(),
    ]),
    builder: (context, _) {
      final orders = widget.store.orders;
      final today = _dateOnly(DateTime.now());
      final due = orders.where((o) => _dateStatus(o, today) == 'Due today' &&
          widget.store.reminderFor(o.id)?.wasSent != true && !o.claimed).length;
      final overdue = orders.where((o) => _dateStatus(o, today) == 'Overdue' &&
          widget.store.reminderFor(o.id)?.wasSent != true && !o.claimed).length;
      final filtered = _select(orders);
      final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ _pageSize;
      final currentPage = _page.clamp(0, lastPage).toInt();
      final displayed = filtered.skip(currentPage * _pageSize).take(_pageSize).toList();
      final from = filtered.isEmpty ? 0 : currentPage * _pageSize + 1;
      final to = currentPage * _pageSize + displayed.length;
      final narrow = MediaQuery.sizeOf(context).width < 720;
      final testStatus = _testStatus();
      return Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: ListView(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, 22, narrow ? 16 : 28, 32),
          children: [
            const PageHeading(title: 'SMS center',
              subtitle: 'Send real SMS using this Android phone\'s default SMS SIM.'),
            const SizedBox(height: 16),
            SurfaceCard(color: AppColors.lightTeal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.sim_card_outlined, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_hasPermission
                      ? 'SMS permission granted • SIM sending available'
                      : 'SMS permission required',
                    style: const TextStyle(fontWeight: FontWeight.w900,
                        color: AppColors.navy))),
                ]),
                const SizedBox(height: 8),
                Text('$due due today • $overdue overdue • '
                    'Automatic: ${widget.store.autoSmsEnabled ? 'ON' : 'OFF'}',
                  style: const TextStyle(color: AppColors.navySoft)),
                if (!_hasPermission) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _smsCapable ? _requestPermission : null,
                    icon: const Icon(Icons.security),
                    label: const Text('Grant SMS permission'),
                  ),
                  if (!_smsCapable) const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('SMS hardware unavailable, or native SMS files are not installed.',
                      style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            SurfaceCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.science_outlined, color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(child: Text('Test SMS', style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.navy))),
                ]),
                const SizedBox(height: 5),
                const Text('Send to a number you own or have permission to test.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: _testPhone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                  decoration: const InputDecoration(labelText: 'Test phone number',
                    hintText: '09171234567', prefixIcon: Icon(Icons.phone_android)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _testMessage,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Test message',
                    alignLabelWithHint: true),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: !_hasPermission || _testing ? null : _sendTest,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_testing ? 'Requesting send...' : 'Send Test SMS'),
                  ),
                ),
                if (_testRequestId != null) ...[
                  const SizedBox(height: 12),
                  Text('Test result: ${testStatus?['status'] ?? 'Waiting...'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  if ((testStatus?['detail'] ?? '').toString().isNotEmpty)
                    Text(testStatus!['detail'].toString(),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('“Sent” is a mobile network result. '
                      'Check the recipient phone to confirm actual receipt.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ],
            )),
            const SizedBox(height: 17),
            const Text('Pickup reminders', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w900, color: AppColors.navy)),
            const SizedBox(height: 5),
            Text(widget.store.autoSmsEnabled
                ? 'One reminder is scheduled near the chosen claim-day time. '
                  'Timing depends on Android battery scheduling.'
                : 'Automatic sending is OFF. Enable it in Settings after a successful test.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() {
                _search = value.trim(); _page = 0;
              }),
              decoration: const InputDecoration(hintText: 'Search name, phone or receipt',
                prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final option in const [
                  'Due & overdue', 'Due today', 'Overdue', 'Sent', 'Failed', 'Claimed', 'All'
                ]) ...[
                  ChoiceChip(
                    label: Text(option), selected: _filter == option,
                    onSelected: (_) => setState(() { _filter = option; _page = 0; }),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Text('Showing $from–$to of ${filtered.length} customers',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
            if (displayed.isEmpty)
              const SurfaceCard(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: Text('No matching customers.')),
              )),
            for (final order in displayed) _orderCard(order, today),
            if (filtered.isNotEmpty) SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(children: [
                Expanded(child: Text('$from–$to / ${filtered.length}')),
                IconButton(tooltip: 'Previous 10',
                  onPressed: currentPage == 0 ? null : () => setState(() => _page = currentPage - 1),
                  icon: const Icon(Icons.chevron_left)),
                Text('${currentPage + 1} / ${lastPage + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(tooltip: 'Next 10',
                  onPressed: currentPage >= lastPage ? null : () => setState(() => _page = currentPage + 1),
                  icon: const Icon(Icons.chevron_right)),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Only message customers who agreed to receive pickup reminders. '
                'SMS plans, rate limits and background delivery depend on your carrier and Android device.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ));
    },
  );

  Widget _orderCard(LaundryOrder order, DateTime today) {
    final sms = widget.store.reminderFor(order.id);
    final dueStatus = order.claimed ? 'Claimed' : _dateStatus(order, today);
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(backgroundColor: AppColors.lightTeal,
              child: Icon(Icons.person_outline, color: AppColors.teal)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.fullName, style: const TextStyle(
                  fontWeight: FontWeight.w900, color: AppColors.navy)),
                Text(order.phoneNumber, style: const TextStyle(
                  color: AppColors.muted, fontSize: 12)),
              ],
            )),
            Text(dueStatus, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: dueStatus == 'Overdue' ? AppColors.danger : AppColors.teal,
            )),
          ]),
          const SizedBox(height: 10),
          Text('${order.receiptId} • ${order.category} • Claim: ${readableDate(order.claimDate)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(sms?.status ?? 'No SMS scheduled', style: TextStyle(
            color: sms?.wasSent == true ? AppColors.teal : AppColors.navySoft,
            fontWeight: FontWeight.w800, fontSize: 12)),
          if (sms != null && sms.nativeDetail.isNotEmpty) Text(sms.nativeDetail,
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (!order.claimed && !order.smsOptIn) OutlinedButton.icon(
              onPressed: () => _recordConsent(order),
              icon: const Icon(Icons.fact_check_outlined, size: 17),
              label: const Text('Confirm SMS consent'),
            ) else if (!order.claimed) OutlinedButton.icon(
              onPressed: _busyOrder == null && sms?.wasSent != true &&
                  sms?.nativeStatus != 'queued' && _smsCapable && _hasPermission
                    ? () => _sendNow(order) : null,
              icon: const Icon(Icons.send_outlined, size: 17),
              label: const Text('Send SMS now'),
            ),
            TextButton.icon(
              onPressed: () => _setClaimed(order, !order.claimed),
              icon: Icon(order.claimed ? Icons.undo : Icons.check_circle_outline,
                  size: 17),
              label: Text(order.claimed ? 'Undo claimed' : 'Mark claimed'),
            ),
          ]),
        ]),
      ),
    );
  }
}
