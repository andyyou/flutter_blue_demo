import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleController extends StatefulWidget {
  const BleController({super.key});

  @override
  State<BleController> createState() => _BleControllerState();
}

class _BleControllerState extends State<BleController> {
  List<ScanResult> _scanResults = []; // 掃描結果
  bool _isScanning = false; // 是否正在掃描
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown; // 藍牙狀態
  BluetoothDevice? _connectedDevice; // 連結的裝置
  List<BluetoothService> _services = [];
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  void _initBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("此裝置不支援藍牙");
      return;
    }
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() => _adapterState = state);
    });
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
    // 等待藍牙開啟
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;
  }

  void _startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      print('藍牙未開啟');
      return;
    }

    print('開始掃描');
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
        });
      });
    } catch (e) {
      print("開始掃描時發生錯誤: $e");
    }
  }

  void _stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _scanResults.clear();
      _isScanning = false;
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      setState(() => _connectedDevice = device);
      print('已連接到設備: ${device.platformName}');
      _discoverServices();
    } catch (e) {
      print('連接設備時發生錯誤: $e');
    }

    // 監聽連接狀態
    device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        print("設備已斷開連接: ${device.disconnectReason?.description}");
        setState(() => _connectedDevice = null);
      }
    });
  }

  void _discoverServices() async {
    if (_connectedDevice == null) return;
    try {
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();
      setState(() => _services = services);
    } catch (e) {
      print('發現服務時發生錯誤: $e');
    }
  }

  Future<void> _readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    try {
      List<int> value = await characteristic.read();
      print('讀取值: ${String.fromCharCodes(value)}');
    } catch (e) {
      print('讀取特徵值時發生錯誤: $e');
    }
  }

  Future<void> _writeCharacteristic(
      BluetoothCharacteristic characteristic, List<int> value) async {
    try {
      await characteristic.write(value);
      print('寫入成功');
    } catch (e) {
      print('寫入特徵值時發生錯誤: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('藍芽裝置'),
      ),
      body: buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }

  Widget buildBody() {
    if (_adapterState == BluetoothAdapterState.off) {
      return const Text('藍牙未開啟');
    }
    if (_connectedDevice != null) {
      return _buildServiceList();
    }
    return _buildScanList();
  }

  Widget _buildScanList() {
    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        return ListTile(
          title: Text(result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.device.remoteId.toString()),
          subtitle: Text(result.device.advName),
          trailing: Text('${result.rssi} dBm'),
          onTap: () => _connectToDevice(result.device),
        );
      },
    );
  }

  Widget _buildServiceList() {
    return ListView.builder(
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return ExpansionTile(
          title: Text('Service: ${service.uuid}'),
          children: service.characteristics
              .map((c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => _readCharacteristic(c),
                    onWritePressed: (value) => _writeCharacteristic(c, value),
                  ))
              .toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}

class CharacteristicTile extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final VoidCallback onReadPressed;
  final Function(List<int>) onWritePressed;

  const CharacteristicTile({
    super.key,
    required this.characteristic,
    required this.onReadPressed,
    required this.onWritePressed,
  });

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  final TextEditingController _writeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('Characteristic: ${widget.characteristic.uuid}'),
      subtitle: Text('Properties: ${widget.characteristic.properties}'),
      children: [
        ListTile(
          title: const Text('讀取'),
          trailing: IconButton(
            icon: const Icon(Icons.read_more),
            onPressed: widget.onReadPressed,
          ),
        ),
        ListTile(
          title: const Text('寫入'),
          subtitle: TextField(
            controller: _writeController,
            decoration: const InputDecoration(
              hintText: '輸入 16 進制值 (e.g., 01 02 03)',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue, width: 2.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey, width: 1.0),
              ),
              fillColor: Colors.white,
              filled: true,
            ),
          ),
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('寫入'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              // 將輸入的十六進制字符串轉換為字節列表
              List<int> value = _writeController.text
                  .split(' ')
                  .map((s) => int.parse(s, radix: 16))
                  .toList();
              widget.onWritePressed(value);
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _writeController.dispose();
    super.dispose();
  }
}
