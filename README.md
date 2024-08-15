# Flutter 藍芽通訊使用 flutter_blue_plus

隨著藍芽普及成為生活中幾乎是不可或缺的一部分，它實現了裝置之間無線傳輸連線。在開發行動應用程式時，尤其涉及 IoT 或週邊裝置如耳機的應用程式時，整合藍芽功能就變得額外重要。Flutter 基於活躍的社群，支援了許多套件，其中 `flutter_blue_plus` 便是一個比較多人使用的藍牙套件。

在這篇文章我們將探討如何使用 `flutter_blue_plus` 實作藍芽通訊。

`flutter_blue_plus` 是一個 Flutter 套件，其簡化了藍芽低功耗傳輸 Bluetooth Low Energy Communication (BLE)。這個套件是基於 `flutter_blue` 的強化版，也就是改善了原版的穩定性、修正問題以及提供了新功能。該套件讓我們可以執行例如掃描附近藍芽裝置並連線、讀取、寫入特徵值 Characteristics，訂閱通知等任務。

首先，讓我們建立一個範例專案並安裝 `flutter_blue_plus`：

```sh
$ flutter create blue_demo
$ flutter pub add flutter_blue_plus
```

## 掃描 BLE 裝置

接著，我們的第一步便是掃描附近的藍芽裝置。我們在專案的 `lib` 目錄下建立一個 `ble_scanner.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleScanner extends StatefulWidget {
  const BleScanner({super.key});

  @override
  State<BleScanner> createState() => _BleScannerState();
}

class _BleScannerState extends State<BleScanner> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    // 開始掃描時，先清空掃描結果
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 120),
      );

      // 監聽掃描結果
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
        });
      });
    } catch (e) {
      print("開始掃描時發生錯誤: $e");
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('掃描藍芽裝置')),
      body: ListView.builder(
          itemCount: _scanResults.length,
          itemBuilder: (context, index) {
            final result = _scanResults[index];
            return ListTile(
              title: Text(result.device.platformName),
              subtitle: Text(result.device.remoteId.toString()),
              trailing: Text(result.rssi.toString()),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}
```

在上面範例，我們建立了一個簡單的 `BleScanner` 組件並使用 `flutter_blue_plus` 掃描取得附近的裝置，一旦取得掃描執行 `scanResults` 並加入狀態。
