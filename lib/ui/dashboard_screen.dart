import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/bluetooth_provider.dart';
import '../ble/device_profile.dart';
import 'package:flutter/services.dart';
import '../logic/protocol_handler.dart';
import 'package:share_plus/share_plus.dart';

class DashboardScreen extends StatefulWidget {
  final BluetoothProvider provider;

  const DashboardScreen({super.key, required this.provider});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _atController = TextEditingController();
  final TextEditingController _protoCDataController = TextEditingController(text: '00 01');
  int _protoCCmd = 0x03;
  bool _showLogs = false;

  void _shareLogs() {
    final allLogs = widget.provider.logs.join('\n');
    Share.share(allLogs, subject: 'Scent Device Logs');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Perfume Control', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showLogs ? Icons.terminal : Icons.terminal_outlined, 
              color: _showLogs ? Colors.blueAccent : Colors.white70),
            tooltip: 'Консоль',
            onPressed: () => setState(() => _showLogs = !_showLogs),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            tooltip: 'Поделиться логами',
            onPressed: () => _shareLogs(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Настройки',
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Настройки будут доступны в следующем обновлении')),
               );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          bottom: false, // Scaffold usually handles top/bottom, but we want extra at bottom
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionSection(),
                const SizedBox(height: 24),
                
                if (widget.provider.isConnected) ...[
                  _buildMainControls(),
                  const SizedBox(height: 24),
                  _buildScentGrid(),
                  const SizedBox(height: 24),
                  _buildAdvancedTools(),
                ] else ...[
                  _buildScanningSection(),
                ],
                
                if (_showLogs) ...[
                  const SizedBox(height: 24),
                  _buildLiveLogSection(),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedTools() {
    return ExpansionTile(
      title: Text('Инструменты отладки (BW16)', 
        style: GoogleFonts.outfit(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
      iconColor: Colors.orangeAccent,
      collapsedIconColor: Colors.white38,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildResearchPanel(),
        ),
      ],
    );
  }

  Widget _buildConnectionSection() {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.provider.isConnected ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.provider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: widget.provider.isConnected ? Colors.blueAccent : Colors.redAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.provider.deviceDisplayName,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.provider.isConnected ? 'Подключено' : 'Отключено',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          if (widget.provider.isConnected)
            TextButton(
              onPressed: () => widget.provider.disconnect(),
              child: const Text('ОТКЛЮЧИТЬ', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          else if (widget.provider.isResearchMode)
            const Chip(
              label: Text('RESEARCH', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              backgroundColor: Colors.orangeAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildScanningSection() {
    final devices = widget.provider.discoveredDevices;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Доступные устройства', 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.provider.isScanning)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)))
            else
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                onPressed: () => widget.provider.startScan(),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (devices.isEmpty && !widget.provider.isScanning)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.bluetooth_searching, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text('Устройств не найдено', style: GoogleFonts.outfit(color: Colors.white38)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => widget.provider.startScan(),
                    child: const Text('Начать поиск'),
                  ),
                ],
              ),
            ),
          ),
        for (var result in devices) ...[
          _buildDeviceListItem(result),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildDeviceListItem(ScanResult result) {
    final name = result.device.platformName.isNotEmpty ? result.device.platformName : "Unknown Device";
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.bluetooth, color: Colors.blueAccent.withValues(alpha: 0.6), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(result.device.remoteId.toString(), style: GoogleFonts.firaCode(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => widget.provider.connectToDevice(result),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Подключить', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainControls() {
    return Row(
      children: [
        Expanded(
          child: _controlCard(
            'Power', 
            Icons.power_settings_new, 
            widget.provider.isPowerOn, 
            (val) => widget.provider.togglePower(),
            Colors.greenAccent
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _controlCard(
            'Ionization', 
            Icons.waves, 
            widget.provider.ionEnabled, 
            (val) => widget.provider.toggleIon(),
            Colors.blueAccent
          ),
        ),
      ],
    );
  }

  Widget _buildScentGrid() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++) ...[
          _scentCard(i),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _scentCard(int index) {
    final intensity = widget.provider.getIntensity(index);
    final levels = ['Off', 'Light', 'Fresh', 'Rich'];
    
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('${index + 1}', 
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.provider.scentNames[index] ?? 'Channel ${index + 1}',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('Уровень аромата: ${levels[intensity]}',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: intensity > 0,
                onChanged: (val) => widget.provider.setChannelIntensity(index, val ? 1 : 0),
                activeColor: Colors.blueAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int level = 0; level <= 3; level++)
                _intensityButton(index, level, levels[level]),
            ],
          ),
          const SizedBox(height: 16),
          _fluidLevelBar(widget.provider.getFluidLevel(index)),
        ],
      ),
    );
  }

  Widget _intensityButton(int channel, int level, String label) {
    bool isSelected = widget.provider.getIntensity(channel) == level;
    return InkWell(
      onTap: () => widget.provider.setChannelIntensity(channel, level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _fluidLevelBar(int percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Остаток жидкости', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text('$percentage%', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 20 ? Colors.blueAccent.withValues(alpha: 0.6) : Colors.redAccent.withValues(alpha: 0.6),
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _controlCard(String title, IconData icon, bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: value ? activeColor : Colors.white24, size: 28),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }

  // --- RESEARCH MODE PANELS ---

  Widget _buildResearchPanel() {
    return Column(
      children: [
        // Protocol Overrides
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.settings_suggest, 'Выбор протокола (Override)'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (var type in ProtocolType.values)
                    ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: widget.provider.manualProtocol == type,
                      onSelected: (val) => widget.provider.setManualProtocol(val ? type : null),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      selectedColor: Colors.blueAccent,
                      labelStyle: TextStyle(color: widget.provider.manualProtocol == type ? Colors.white : Colors.white54, fontSize: 10),
                    ),
                  ChoiceChip(
                    label: const Text('AUTO'),
                    selected: widget.provider.manualProtocol == null,
                    onSelected: (val) => widget.provider.setManualProtocol(null),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    selectedColor: Colors.greenAccent,
                    labelStyle: TextStyle(color: widget.provider.manualProtocol == null ? Colors.black : Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Manual HEX Injection
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.terminal, 'Инъекция HEX'),
              const SizedBox(height: 12),
              TextField(
                controller: _hexController,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Пример: AA 55 01 01 01',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: () => widget.provider.sendRawHex(_hexController.text),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AT Console
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.code, 'AT Консоль'),
              const SizedBox(height: 12),
              TextField(
                controller: _atController,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Команда (например, AT+NAME?)',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.orangeAccent),
                    onPressed: () => widget.provider.sendATCommand(_atController.text),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  _QuickBtn(label: 'AT', onTap: () => widget.provider.sendATCommand('AT')),
                  _QuickBtn(label: 'VER', onTap: () => widget.provider.sendATCommand('AT+VERSION')),
                  _QuickBtn(label: 'MAC', onTap: () => widget.provider.sendATCommand('AT+ADDR?')),
                  _QuickBtn(label: 'GMR', onTap: () => widget.provider.sendATCommand('AT+GMR')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Protocol C Builder
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.build, 'Protocol C Packet Builder'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _inputField(
                      label: 'CMD (HEX)', 
                      hint: '03', 
                      onChanged: (val) => setState(() => _protoCCmd = int.tryParse(val, radix: 16) ?? 0x03)
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _protoCDataController,
                      style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Params (HEX)',
                        hintText: '00 01',
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.greenAccent),
                    onPressed: () {
                      final data = _protoCDataController.text.split(' ').where((s) => s.isNotEmpty).map((s) => int.parse(s, radix: 16)).toList();
                      widget.provider.sendRawHex(widget.provider.hexFromBytes(ProtocolHandler.buildProtocolC(_protoCCmd, data)));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildChecksumPreview(),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Command Grid
        GlassCard(
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
                    const SizedBox(width: 12),
                    _TestSet(
                      label: 'BW16 / Realtek',
                      onTest: (cmd) {
                        if (cmd == 'Probe') widget.provider.probeBW16();
                        if (cmd == 'GMR') widget.provider.sendATCommand('AT+GMR');
                        if (cmd == 'Help') widget.provider.sendATCommand('AT+HELP');
                        if (cmd == 'Reset') widget.provider.sendATCommand('AT+RST');
                      },
                      isResearch: true,
                      customActions: ['Probe', 'GMR', 'Help', 'Reset'],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orangeAccent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.provider.runAutoProbe(),
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'АВТО-ЗОНДИРОВАНИЕ',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveLogSection() {
    return Column(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(Icons.history, 'Лог обмена данными (Live)'),
              const SizedBox(height: 12),
              Container(
                height: 200, // Reduced height
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  reverse: false,
                  itemCount: widget.provider.logs.length,
                  itemBuilder: (context, index) {
                    final log = widget.provider.logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: GoogleFonts.firaCode(
                          color: log.contains('TX') ? Colors.blueAccent : 
                                 log.contains('RX') ? Colors.greenAccent : 
                                 log.contains('ERR') ? Colors.redAccent :
                                 log.contains('String') ? Colors.white : Colors.white70,
                          fontSize: 10, // Slightly smaller
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
  final List<String>? customActions;

  const _TestSet({required this.label, required this.onTest, this.isResearch = false, this.customActions});

  @override
  Widget build(BuildContext context) {
    final actions = customActions ?? ['ON', 'OFF', 'Int 1', 'Sync'];
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
              for (var action in actions)
                _QuickBtn(label: action, onTap: () => onTest(action)),
              if (isResearch && customActions == null) ...[
                _QuickBtn(label: 'P02', onTap: () => onTest('Probe 02')),
                _QuickBtn(label: 'P04', onTap: () => onTest('Probe 04')),
                _QuickBtn(label: 'P06', onTap: () => onTest('Probe 06')),
              ],
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

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const GlassCard({super.key, required this.child, this.padding, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
