package com.example.caitlyn_laundry_shop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsBridge: SmsNativeBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = SmsNativeBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        smsBridge?.register()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsBridge?.handlePermissionResult(requestCode, grantResults)
    }
}
