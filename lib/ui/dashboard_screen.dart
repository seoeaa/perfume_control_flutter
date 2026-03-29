import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bluetooth_provider.dart';
import 'widgets/glass_card.dart';
import 'support_screen.dart';
import '../ble/device_profile.dart';
import '../logic/protocol_handler.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bluetoothProvider = Provider.of<BluetoothProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Header & Connection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bluetoothProvider.deviceDisplayName,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: bluetoothProvider.isConnected
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (bluetoothProvider.isConnected
                                              ? Colors.greenAccent
                                              : Colors.redAccent)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                bluetoothProvider.isConnected
                                    ? 'Подключено'
                                    : 'Нет соединения',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // New Utility Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildUtilityButton(
                          context,
                          icon: Icons.bluetooth_searching,
                          label: 'Скан',
                          color: Colors.blueAccent,
                          onTap: () {
                            bluetoothProvider.scanAndConnect();
                            _showDevicePicker(context, bluetoothProvider);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildUtilityButton(
                          context,
                          icon: Icons.settings_suggest,
                          label: 'Плата',
                          color: Colors.white70,
                          onTap: () => _showProtocolDialog(context, bluetoothProvider),
                        ),
                        const SizedBox(width: 12),
                        _buildUtilityButton(
                          context,
                          icon: Icons.terminal,
                          label: 'Логи',
                          color: Colors.amberAccent,
                          onTap: () => _showLogConsole(context),
                        ),
                        const SizedBox(width: 12),
                        _buildUtilityButton(
                          context,
                          icon: Icons.help_outline,
                          label: 'Инфо',
                          color: Colors.lightBlueAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SupportScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Управление ароматами',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scent Channels
                  ...List.generate(3, (index) {
                    final scentName = bluetoothProvider.scentNames[index] ?? 'Аромат ${String.fromCharCode(65 + index)}';
                    final channelIntensity = bluetoothProvider.getIntensity(index);
                    final isActive = channelIntensity > 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GlassCard(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.blueAccent.withValues(alpha: 0.2)
                                              : Colors.white10,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: requestIdToIcon(index, isActive),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    scentName,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit, size: 14, color: Colors.white38),
                                                  padding: const EdgeInsets.only(left: 8),
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _editScentName(context, bluetoothProvider, index),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Остаток: ${bluetoothProvider.getFluidLevel(index)}%',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isActive,
                                  onChanged: (on) => bluetoothProvider.setChannelIntensity(index, on ? 2 : 0),
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: Colors.blueAccent,
                                  inactiveThumbColor: Colors.white54,
                                  inactiveTrackColor: Colors.white10,
                                ),
                              ],
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _LevelBtn(
                                        label: 'Легкий',
                                        active: channelIntensity == 1,
                                        onTap: () => bluetoothProvider.setChannelIntensity(index, 1),
                                      ),
                                    ),
                                    Expanded(
                                      child: _LevelBtn(
                                        label: 'Средний',
                                        active: channelIntensity == 2,
                                        onTap: () => bluetoothProvider.setChannelIntensity(index, 2),
                                      ),
                                    ),
                                    Expanded(
                                      child: _LevelBtn(
                                        label: 'Насыщ.',
                                        active: channelIntensity == 3,
                                        onTap: () => bluetoothProvider.setChannelIntensity(index, 3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  Text(
                    'Дополнительно',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Extra Switches with better layout
                  Row(
                    children: [
                      Expanded(
                        child: _ExtraControlCard(
                          label: 'Ионизация',
                          icon: Icons.air,
                          value: bluetoothProvider.ionEnabled,
                          onChanged: (_) => bluetoothProvider.toggleIon(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ExtraControlCard(
                          label: 'Питание',
                          icon: Icons.power_settings_new,
                          value: bluetoothProvider.isPowerOn,
                          onChanged: (_) => bluetoothProvider.togglePower(),
                          isWarning: true,
                        ),
                      ),
                    ],
                  ),

                  if (bluetoothProvider.isResearchMode) ...[
                    const SizedBox(height: 32),
                    Text(
                      'RESEARCH MODE: 64507067',
                      style: GoogleFonts.outfit(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ResearchControls(provider: bluetoothProvider),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget requestIdToIcon(int index, bool active) {
    IconData icon;
    switch (index) {
      case 0:
        icon = Icons.spa;
        break;
      case 1:
        icon = Icons.local_florist;
        break;
      case 2:
        icon = Icons.grass;
        break;
      default:
        icon = Icons.bubble_chart;
    }
    return Icon(
      icon,
      color: active ? Colors.blueAccent : Colors.white24,
      size: 20,
    );
  }

  void _showDevicePicker(BuildContext context, BluetoothProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<BluetoothProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Поиск устройств',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (provider.isScanning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blueAccent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (provider.discoveredDevices.isEmpty && !provider.isScanning)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            'Устройства не найдены',
                            style: GoogleFonts.outfit(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: provider.discoveredDevices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final result = provider.discoveredDevices[index];
                        final name = result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : 'Неизвестное устройство';
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () {
                              provider.connectToDevice(result.device);
                              Navigator.pop(context); // Close picker
                              _showLogConsole(context); // Open logs
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.bluetooth, color: Colors.blueAccent),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                            color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        result.device.remoteId.toString(),
                                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _showProtocolDialog(BuildContext context, BluetoothProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Настройка платы',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _protocolOption(
                context,
                provider,
                title: 'Авто-определение',
                subtitle: 'Рекомендуется',
                type: null,
              ),
              const Divider(color: Colors.white10),
              _protocolOption(
                context,
                provider,
                title: 'Тип 1 (7E)',
                subtitle: 'Стандарт (свежие платы)',
                type: ProtocolType.a,
              ),
              const Divider(color: Colors.white10),
              _protocolOption(
                context,
                provider,
                title: 'Тип 2 (A5 / 55)',
                subtitle: 'Fresh Air / Aromely',
                type: ProtocolType.b,
              ),
              const Divider(color: Colors.white10),
              _protocolOption(
                context,
                provider,
                title: 'Тип 3 (AA 55)',
                subtitle: 'Специфичная плата',
                type: ProtocolType.c,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Закрыть', style: GoogleFonts.outfit(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _protocolOption(
    BuildContext context,
    BluetoothProvider provider, {
    required String title,
    required String subtitle,
    required ProtocolType? type,
  }) {
    final isSelected = provider.manualProtocol == type;
    return ListTile(
      onTap: () {
        provider.setManualProtocol(type);
        Navigator.pop(context);
      },
      title: Text(
        title,
        style: GoogleFonts.outfit(
          color: isSelected ? Colors.greenAccent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
    );
  }

  Widget _buildUtilityButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogConsole(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<BluetoothProvider>(
              builder: (context, provider, _) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Логи подключения',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.white54),
                                onPressed: () {
                                  final text = provider.logs.join('\n');
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Логи скопированы')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_sweep, color: Colors.white54),
                                onPressed: () => provider.clearLogs(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.logs.length,
                            itemBuilder: (context, index) {
                              // Reversed to show newest at bottom if we want, 
                              // but standard log is usually top-down. 
                              // Let's keep it index based.
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  provider.logs[index],
                                  style: GoogleFonts.firaCode(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _editScentName(BuildContext context, BluetoothProvider provider, int index) {
    final controller = TextEditingController(text: provider.scentNames[index]);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Название аромата ${String.fromCharCode(65 + index)}',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Название',
              labelStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: GoogleFonts.outfit(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                provider.updateScentName(index, controller.text);
                Navigator.pop(context);
              },
              child: Text('Сохранить', style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _ResearchControls extends StatefulWidget {
  final BluetoothProvider provider;
  const _ResearchControls({required this.provider});

  @override
  State<_ResearchControls> createState() => _ResearchControlsState();
}

class _ResearchControlsState extends State<_ResearchControls> {
  final TextEditingController _atController = TextEditingController();
  final TextEditingController _protoCDataController = TextEditingController();
  int _protoCCmd = 0x01;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Protocol C Builder
        GlassCard(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.construction, 'Конструктор Protocol C (AA 55)'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _inputField(
                      label: 'Cmd (HEX)',
                      hint: '01',
                      onChanged: (v) => setState(() => _protoCCmd = int.tryParse(v, radix: 16) ?? 0x01),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _protoCDataController,
                      style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Data Bytes (HEX)',
                        hintText: '01 01',
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildChecksumPreview(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final data = _protoCDataController.text
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .map((s) => int.parse(s, radix: 16))
                        .toList();
                    widget.provider.sendRawHex(
                      ProtocolHandler.buildProtocolC(_protoCCmd, data)
                          .map((b) => b.toRadixString(16).padLeft(2, '0'))
                          .join(' '),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Собрать и Отправить'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AT Console
        GlassCard(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.terminal, 'AT Консоль'),
              const SizedBox(height: 16),
              TextField(
                controller: _atController,
                style: GoogleFonts.firaCode(color: Colors.amberAccent),
                decoration: InputDecoration(
                  labelText: 'Команда (напр. AT+NAME?)',
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.amberAccent),
                    onPressed: () {
                      widget.provider.sendATCommand(_atController.text);
                      _atController.clear();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickBtn(label: 'AT', onTap: () => widget.provider.sendATCommand('AT')),
                    _QuickBtn(label: 'NAME?', onTap: () => widget.provider.sendATCommand('AT+NAME?')),
                    _QuickBtn(label: 'VERSION', onTap: () => widget.provider.sendATCommand('AT+VERSION')),
                    _QuickBtn(label: 'ADDR?', onTap: () => widget.provider.sendATCommand('AT+ADDR?')),
                    _QuickBtn(label: 'BAUD?', onTap: () => widget.provider.sendATCommand('AT+BAUD?')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Protocol Tests
        GlassCard(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.flash_on, 'Быстрые тесты протоколов'),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TestSet(
                      label: 'Proto A (7E)',
                      onTest: (cmd) => widget.provider.testProtocolCommand(ProtocolType.a, cmd),
                    ),
                    const SizedBox(width: 12),
                    _TestSet(
                      label: 'Proto B (A5)',
                      onTest: (cmd) => widget.provider.testProtocolCommand(ProtocolType.b, cmd),
                    ),
                    const SizedBox(width: 12),
                    _TestSet(
                      label: 'Proto C (AA)',
                      onTest: (cmd) => widget.provider.testProtocolCommand(ProtocolType.c, cmd),
                      isResearch: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Log Viewer
        GlassCard(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.history, 'Лог обмена данными (Live)'),
              const SizedBox(height: 12),
              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  reverse: true, // Show latest at bottom but scrollable
                  itemCount: widget.provider.logs.length,
                  itemBuilder: (context, index) {
                    final log = widget.provider.logs[widget.provider.logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: GoogleFonts.firaCode(
                          color: log.contains('RX') ? Colors.greenAccent : 
                                 log.contains('TX') ? Colors.blueAccent : 
                                 log.contains('ERROR') ? Colors.redAccent : Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                    TextButton.icon(
                      onPressed: () {
                        final allLogs = widget.provider.logs.join('\n');
                        Clipboard.setData(ClipboardData(text: allLogs));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Логи скопированы в буфер обмена')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Копировать', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => widget.provider.clearLogs(),
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Очистить', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.white38),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.orangeAccent, size: 20),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _inputField({required String label, required String hint, required ValueChanged<String> onChanged}) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildChecksumPreview() {
    try {
      final data = _protoCDataController.text
          .split(' ')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s, radix: 16))
          .toList();
      final packet = ProtocolHandler.buildProtocolC(_protoCCmd, data);
      final hex = packet.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      return Text(
        'Итог: $hex',
        style: GoogleFonts.firaCode(color: Colors.greenAccent, fontSize: 11),
      );
    } catch (_) {
      return const Text('Ошибка формата', style: TextStyle(color: Colors.redAccent, fontSize: 11));
    }
  }
}

class _TestSet extends StatelessWidget {
  final String label;
  final Function(String) onTest;
  final bool isResearch;

  const _TestSet({required this.label, required this.onTest, this.isResearch = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.outfit(color: isResearch ? Colors.orangeAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _QuickBtn(label: 'ON', onTap: () => onTest('Power ON')),
              _QuickBtn(label: 'OFF', onTap: () => onTest('Power OFF')),
              if (isResearch) ...[
                _QuickBtn(label: 'P02', onTap: () => onTest('Probe 02')),
                _QuickBtn(label: 'P04', onTap: () => onTest('Probe 04')),
              ],
              _QuickBtn(label: 'Sync', onTap: () => onTest('Sync Time')),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(40, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _ExtraControlCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isWarning;

  const _ExtraControlCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isWarning && value 
                    ? Colors.redAccent.withValues(alpha: 0.2) 
                    : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isWarning && value ? Colors.redAccent : Colors.white70,
                  size: 20,
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: isWarning ? Colors.redAccent : Colors.blueAccent,
                inactiveThumbColor: Colors.white54,
                inactiveTrackColor: Colors.white10,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ? 'Включено' : 'Выключено', // On/Off
            style: GoogleFonts.outfit(
              color: value 
                ? (isWarning ? Colors.redAccent : Colors.blueAccent)
                : Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LevelBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: active ? Colors.black87 : Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
