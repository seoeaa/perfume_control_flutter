import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bluetooth_provider.dart';
import 'widgets/glass_card.dart';
import 'support_screen.dart';

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
                            'LI Perfume',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
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
                                          .withOpacity(0.5),
                                      blurRadius: 6,
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showLogConsole(context),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.terminal,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SupportScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.help_outline,
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              bluetoothProvider.scanAndConnect();
                              _showDevicePicker(context, bluetoothProvider);
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.bluetooth_searching,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    final labels = ['Аромат A', 'Аромат B', 'Аромат C'];
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
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.blueAccent.withOpacity(0.2)
                                            : Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: requestIdToIcon(index, isActive),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          labels[index],
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                  ],
                                ),
                                Switch(
                                  value: isActive,
                                  onChanged: (on) => bluetoothProvider.setChannelIntensity(index, on ? 2 : 0),
                                  activeColor: Colors.white,
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
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                            color: Colors.white.withOpacity(0.05),
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
                    ? Colors.redAccent.withOpacity(0.2) 
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
                activeColor: Colors.white,
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
                    color: Colors.black.withOpacity(0.1),
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
