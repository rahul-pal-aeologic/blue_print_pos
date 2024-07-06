import 'dart:convert';

import 'package:blue_print_pos/blue_print_pos.dart';
import 'package:blue_print_pos/models/models.dart';
import 'package:blue_print_pos/receipt/receipt.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BluePrintPos _bluePrintPos = BluePrintPos.instance;
  List<BlueDevice> _blueDevices = <BlueDevice>[];
  BlueDevice? _selectedDevice;
  bool _isLoading = false;
  int _loadingAtIndex = -1;
  @override
  void initState() {
    super.initState();
    requestBluetoothPermissions();
  }

  Future<void> requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetooth]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.location]!.isGranted) {
      // Permissions are granted, proceed with Bluetooth operations
    } else {
      // Permissions are not granted, handle accordingly
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Blue Print Pos'),
        ),
        body: SafeArea(
          child: _isLoading && _blueDevices.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              : _blueDevices.isNotEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Column(
                            children: List<Widget>.generate(_blueDevices.length,
                                (int index) {
                              return Row(
                                children: <Widget>[
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _blueDevices[index].address ==
                                              (_selectedDevice?.address ?? '')
                                          ? _onDisconnectDevice
                                          : () => _onSelectDevice(index),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              _blueDevices[index].name,
                                              style: TextStyle(
                                                color:
                                                    _selectedDevice?.address ==
                                                            _blueDevices[index]
                                                                .address
                                                        ? Colors.blue
                                                        : Colors.black,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _blueDevices[index].address,
                                              style: TextStyle(
                                                color:
                                                    _selectedDevice?.address ==
                                                            _blueDevices[index]
                                                                .address
                                                        ? Colors.blueGrey
                                                        : Colors.grey,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_loadingAtIndex == index && _isLoading)
                                    Container(
                                      height: 24.0,
                                      width: 24.0,
                                      margin: const EdgeInsets.only(right: 8.0),
                                      child: const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.blue,
                                        ),
                                      ),
                                    ),
                                  if (!_isLoading &&
                                      _blueDevices[index].address ==
                                          (_selectedDevice?.address ?? ''))
                                    TextButton(
                                      onPressed: _onPrintReceipt,
                                      child: Container(
                                        color: _selectedDevice == null
                                            ? Colors.grey
                                            : Colors.blue,
                                        padding: const EdgeInsets.all(8.0),
                                        child: const Text(
                                          'Test Print',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      style: ButtonStyle(
                                        backgroundColor: MaterialStateProperty
                                            .resolveWith<Color>(
                                          (Set<MaterialState> states) {
                                            if (states.contains(
                                                MaterialState.pressed)) {
                                              return Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.5);
                                            }
                                            return Theme.of(context)
                                                .primaryColor;
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const <Widget>[
                          Text(
                            'Scan bluetooth device',
                            style: TextStyle(fontSize: 24, color: Colors.blue),
                          ),
                          Text(
                            'Press button scan',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isLoading ? null : _onScanPressed,
          child: const Icon(Icons.search),
          backgroundColor: _isLoading ? Colors.grey : Colors.blue,
        ),
      ),
    );
  }

  Future<void> _onScanPressed() async {
    setState(() => _isLoading = true);
    _bluePrintPos.scan().then((List<BlueDevice> devices) {
      if (devices.isNotEmpty) {
        setState(() {
          _blueDevices = devices;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  void _onDisconnectDevice() {
    _bluePrintPos.disconnect().then((ConnectionStatus status) {
      if (status == ConnectionStatus.disconnect) {
        setState(() {
          _selectedDevice = null;
        });
      }
    });
  }

  void _onSelectDevice(int index) {
    setState(() {
      _isLoading = true;
      _loadingAtIndex = index;
    });
    final BlueDevice blueDevice = _blueDevices[index];
    _bluePrintPos.connect(blueDevice).then((ConnectionStatus status) {
      if (status == ConnectionStatus.connected) {
        setState(() => _selectedDevice = blueDevice);
      } else if (status == ConnectionStatus.timeout) {
        _onDisconnectDevice();
      } else {
        print('$runtimeType - something wrong');
      }
      setState(() => _isLoading = false);
    });
  }

  Future<void> _onPrintReceipt() async {
    /// Example for Print Image
    final ByteData logoBytes = await rootBundle.load(
      'assets/logo.jpg',
    );

    /// Example for Print Text
    final ReceiptSectionText receiptText = ReceiptSectionText();
    receiptText.addText(
      '*************************',
    );
    // receiptText.addImage(
    //   base64.encode(Uint8List.view(logoBytes.buffer)),
    //   width: 100,
    // );
    // receiptText.addImage(
    //   base64.encode(Uint8List.view(logoBytes.buffer)),
    //   width: 200,
    // );
    // receiptText.addImage(
    //   base64.encode(Uint8List.view(logoBytes.buffer)),
    //   width: 300,
    // );
    // receiptText.addImage(
    //   base64.encode(Uint8List.view(logoBytes.buffer)),
    //   width: 400,
    // );
    receiptText.addSpacer();
    receiptText.addText(
      'BITSATOM - FHUNGER',
      size: ReceiptTextSizeType.medium,
      style: ReceiptTextStyleType.bold,
    );
    receiptText.addText(
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit',
      size: ReceiptTextSizeType.small,
    );
    receiptText.addSpacer(useDashed: true);
    receiptText.addLeftRightText('Time', '6 July 2024, 12:43 PM');
    receiptText.addSpacer(useDashed: true);
    receiptText.addLeftRightText(
      'Hi AMIT ',
      'Rp30.000',
      leftStyle: ReceiptTextStyleType.normal,
      rightStyle: ReceiptTextStyleType.bold,
    );
    receiptText.addLeftRightText(
      'Hi AMIT ',
      'Rp   30.000',
      leftStyle: ReceiptTextStyleType.normal,
      rightStyle: ReceiptTextStyleType.bold,
    );
    receiptText.addLeftRightText(
      'Hi AMIT ',
      'Rp30.000',
      leftStyle: ReceiptTextStyleType.normal,
      rightStyle: ReceiptTextStyleType.bold,
    );
    receiptText.addSpacer(useDashed: true);
    receiptText.addLeftRightText(
      'Payment',
      'Rp30.000',
      leftStyle: ReceiptTextStyleType.normal,
      rightStyle: ReceiptTextStyleType.bold,
    );
    receiptText.addSpacer(useDashed: true);
    receiptText.addText(
      '*************************',
    );

    receiptText.addSpacer(useDashed: true, count: 15);

    await _bluePrintPos.printReceiptText(receiptText,
        paperSize: PaperSize.mm72, useRaster: true);

    /// Example for print QR
    // await _bluePrintPos.printQR('okokok', size: 250);

    //   /// Text after QR
    //   final ReceiptSectionText receiptSecondText = ReceiptSectionText();
    //   receiptSecondText.addText('Powered by ayeee',
    //       size: ReceiptTextSizeType.small);
    //   receiptSecondText.addSpacer();
    //   receiptSecondText.addLeftRightText(
    //     'Payment',
    //     'Cash',
    //     leftStyle: ReceiptTextStyleType.normal,
    //     rightStyle: ReceiptTextStyleType.normal,
    //   );
    //   await _bluePrintPos.printReceiptText(receiptSecondText);
    // }
  }
}
