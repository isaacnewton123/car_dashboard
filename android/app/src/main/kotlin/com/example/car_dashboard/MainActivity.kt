package com.example.car_dashboard

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var bluetoothHandler: BluetoothClassicHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bluetoothHandler = BluetoothClassicHandler(this, flutterEngine.dartExecutor.binaryMessenger)
        bluetoothHandler?.register()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bluetoothHandler?.dispose()
        bluetoothHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bluetoothHandler?.onPermissionsResult(requestCode, grantResults)
    }
}
