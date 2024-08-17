# Flutter 藍芽通訊使用 flutter_blue_plus

隨著藍芽普及成為生活中幾乎是不可或缺的一部分，它實現了裝置之間無線傳輸連線。在開發行動應用程式時，尤其涉及 IoT 或週邊裝置如耳機的應用程式時，整合藍芽功能就變得額外重要。Flutter 基於活躍的社群，支援了許多套件，其中 `flutter_blue_plus` 便是一個比較多人使用的藍牙套件。

在這篇文章我們將探討如何使用 `flutter_blue_plus` 實作藍牙低功耗(BLE)通訊。

`flutter_blue_plus` 是一個 Flutter 套件，其簡化了藍芽低功耗傳輸 Bluetooth Low Energy Communication (BLE)。這個套件是基於 `flutter_blue` 的強化版，也就是改善了原版的穩定性、修正問題以及提供了新功能。該套件讓我們可以執行例如掃描附近藍芽裝置並連線、讀取、寫入特徵值 Characteristics，訂閱通知等任務。

## 環境設定

首先，讓我們建立一個範例專案並安裝 `flutter_blue_plus`：

```sh
$ flutter create blue_demo
$ flutter pub add flutter_blue_plus
```

### Android 設定

對於 Android 系統首先須確認 `minSdkVersion` 是 21 以上， `flutter_blue_plus` 只相容 21 之後的版本。您需要到 `android/app/build.gradle` 確認

```groovy
android {
    namespace = "com.example.blue_demo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion


    defaultConfig {
        // ...
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
    }

    buildTypes {
        // ...
    }
}
```

當然你可以直接設定這邊的版本 ` minSdk = flutter.minSdkVersion` 。不過，我們也可以進一步釐清，到底這個 `flutter.minSdkVersion` 是多少？

這個最小 SDK 版本是由 Flutter 配置決定的，要確定具體的版本號我們須查詢 `flutter/packages/flutter_tools/gradle/flutter.gradle`

```sh
$ which flutter
[您的安裝路徑]/flutter/bin/flutter
$ cd [您的安裝路徑]/flutter/packages/flutter_tools/gradle/
$ cat flutter.gradle

# 接著，您應該會看到下面的設定
def pathToThisDirectory = buildscript.sourceFile.parentFile
apply from: "$pathToThisDirectory/src/main/groovy/flutter.groovy"

# 也就是 flutter/packages/flutter_tools/gradle/src/main/groovy/flutter.groovy
# 您應該可以看到 minSdkVersion

class FlutterExtension {

     /** Sets the compileSdkVersion used by default in Flutter app projects. */
     public final int compileSdkVersion = 34

     /** Sets the minSdkVersion used by default in Flutter app projects. */
     public  final int minSdkVersion = 21
}
```

既然版本為 21 這裡我們就不做任何變更。但確實還有一些地方是可能變更這些設定的。

1. `app/build.gradle`
2. `android/local.properties`
3. `pubspec.yaml`

確認版本無誤之後，接著我們需要設定授權。

#### 無位置權限

在 `android/app/src/main/AndroidManifest.xml` 加入：

```xml
<!-- 告訴 Google Play Store 您的應用使用藍牙低功耗（BLE）
     如果藍牙是必需的，請將 android:required 設置為 "true" -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

<!-- Android 12 中的新藍牙權限
https://developer.android.com/about/versions/12/features/bluetooth-permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- 適用於 Android 11 或更低版本的舊版權限 -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>

<!-- 適用於 Android 9 或更低版本的舊版權限 -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
```

#### 使用精確位置權限

這種設定允許使用位置權限進行藍牙掃描。須包含 ACCESS_FINE_LOCATION 權限。適用於需要位置信息的藍牙應用，例如 iBeacon 支持。

```xml
<!-- 告訴 Google Play Store 您的應用使用藍牙低功耗（BLE）
     如果藍牙是必需的，請將 android:required 設置為 "true" -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

<!-- Android 12 中的新藍牙權限
https://developer.android.com/about/versions/12/features/bluetooth-permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- 適用於 Android 11 或更低版本的舊版權限 -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />

<!-- 適用於 Android 9 或更低版本的舊版權限 -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
```

然後後續掃描時須設定 `androidUsesFineLocation`

```dart
FlutterBluePlus.startScan(timeout: Duration(seconds: 4), androidUsesFineLocation: true);
```

#### Android Proguard 設定

Proguard 是 Android 用於代碼混淆和優化的工具，若您有使用請在 `android/app/proguard-rules.pro` 加入下面設定，避免在發布版本中出現與反射相關的錯誤

```
-keep class com.lib.flutter_blue_plus.* { *; }
```

通常若您看到下面錯誤應該就是此問題：

```
PlatformException(startScan, Field androidScanMode_ for m0.e0 not found. Known fields are
 [private int m0.e0.q, private b3.b0$i m0.e0.r, private boolean m0.e0.s, private static final m0.e0 m0.e0.t,
 private static volatile b3.a1 m0.e0.u], java.lang.RuntimeException: Field androidScanMode_ for m0.e0 not found
```

#### 其他提醒

一般來說，Android 模擬器（Emulator）確實無法完全測試藍牙功能。雖然某些版本的 Android 模擟器提供了有限的藍牙模擬功能，但這通常僅限於非常基本的操作。即使模擬器支持某些藍牙功能，它也無法掃描到您周圍的實際藍牙設備。

### iOS

對於 iOS，我們需要在`ios/Runner/Info.plist ` 加入藍牙使用描述：

```xml
<dict>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>需要使用藍牙來連接和控制設備</string>
```

若需要位置權限請參考[官方文件說明](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)。處理完 `info.plist` 設定之後還需要使用 Xcode 啟用藍芽設定。

Xcode -> Runners -> Targets -> Runner-> Signing & Capabilities -> App Sandbox -> Hardware -> Enable Bluetooth

## 背景執行

⚠️ FlutterBluePlus 不支援背景執行，須自己實作。

## 掃描 BLE 裝置

接著，我們的第一步便是掃描附近的藍芽裝置。我們在專案的 `lib` 目錄下建立一個 `ble_controller.dart`

```dart
import 'dart:async'; // 為了使用 StreamSubscription 進行藍牙狀態監聽
import 'dart:io';    // 為了檢查平台 Platform (Android 或 iOS)
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleController extends StatefulWidget {
  const BleController({super.key});

  @override
  State<BleController> createState() => _BleControllerState();
}

class _BleControllerState extends State<BleController> {
  List<ScanResult> _scanResults = []; // 掃描結果
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown; // 藍牙 Adapter 的當前狀態 (例如開啟或關閉)
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription; // 訂閱藍牙狀態

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  // 初始化藍牙狀態和監聽器
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

    // 等待藍牙適配器處於開啟狀態
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;
  }

  void _startScan() async {
    // 確認藍牙已開啟
    if (_adapterState != BluetoothAdapterState.on) {
      print('藍牙未開啟');
      return;
    }

    // 重置
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    try {
      // 開始掃描藍牙裝置，掃描時間為15秒
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      // 監聽掃描結果並更新 UI
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
        });
      });
    } catch (e) {
      print("開始掃描時發生錯誤: $e");
    }
  }

  // 停止藍牙掃描
  void _stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('藍芽裝置'),
      ),
      body: _buildScanList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
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
```

在上面範例，我們建立了一個簡單的 `BleController` 組件並使用 `flutter_blue_plus` 掃描取得附近的裝置，一旦取得掃描執行 `scanResults` 並加入狀態。

## 連線裝置

在成功掃描到藍牙設備後，下一步就是實現連接功能。在 `_BleControllerState` 加入一個新的變數來追踪當前連接的裝置：

```dart
BluetoothDevice? _connectedDevice;
```

然後是連線：

```dart
void _connectToDevice(BluetoothDevice device) async {
  try {
    await device.connect(autoConnect: false);
    setState(() => _connectedDevice = device);
    print('已連接到設備: ${device.platformName}');
    _discoverServices();
  } catch (e) {
    print('連接設備時發生錯誤: $e');
  }

  // 監聽連接狀態，如果中斷須更新狀態
  device.connectionState.listen((BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      print("設備已斷開連接: ${device.disconnectReason?.description}");
      setState(() => _connectedDevice = null);
    }
  });
}
```

接著修改 `_buildScanList` 方法，讓使用者可以點擊列表項目來連接設備：

```dart
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
```

## 讀取 / 寫入藍牙特徵值

連接到設備後，我們需要檢索提供的服務 Service 和特徵 Characteristic，以便進行讀寫。我們需要新增一個變數來儲存 Service

```dart
List<BluetoothService> _services = [];
```

然後，加入一個檢索服務的方法：

```dart
void _discoverServices() async {
  if (_connectedDevice == null) return;
  try {
    List<BluetoothService> services = await _connectedDevice!.discoverServices();
    setState(() => _services = services);
  } catch (e) {
    print('發現服務時發生錯誤: $e');
  }
}
```

然後就可以實做讀取和寫入：

```dart
Future<void> _readCharacteristic(BluetoothCharacteristic characteristic) async {
  try {
    List<int> value = await characteristic.read();
    print('讀取值: ${String.fromCharCodes(value)}');
  } catch (e) {
    print('讀取特徵值時發生錯誤: $e');
  }
}

Future<void> _writeCharacteristic(BluetoothCharacteristic characteristic, List<int> value) async {
  try {
    await characteristic.write(value);
    print('寫入成功');
  } catch (e) {
    print('寫入特徵值時發生錯誤: $e');
  }
}
```

最後我們提供完整範例程式碼方便您進行理解和閱讀：

```dart
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
```

到此，您應該具備了基本的知識可以參考閱讀官方說明，並且進一步處理實務上需要注意的各種細節和問題。

## 參考資源

- [flutter_blue_plus](https://github.com/boskokg/flutter_blue_plus/blob/3a49658b4a42ae21e06974a80af15c8b72112892/README.md) - 常見錯誤可參考官方說明。
- [minSdkVersion 設定位於何處](https://stackoverflow.com/questions/70485898/where-is-the-value-of-flutter-minsdkversion-in-flutter-project-initialized)
