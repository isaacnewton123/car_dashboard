package com.example.car_dashboard

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

/**
 * Native Bluetooth Classic (RFCOMM/SPP) handler for OBD-II communication.
 *
 * Provides [MethodChannel]-based API for Flutter:
 * - `getBondedDevices` → List of paired devices (auto-requests permission)
 * - `connect(address)` → RFCOMM connection via SPP UUID
 * - `write(data)` → Send bytes to the device
 * - `disconnect` → Close the socket
 * - `isConnected` → Connection status check
 *
 * Incoming data is streamed to Flutter via [EventChannel].
 *
 * Handles Android 12+ (API 31) runtime permission requests automatically.
 */
class BluetoothClassicHandler(
    private val activity: Activity,
    private val binaryMessenger: BinaryMessenger
) {

    companion object {
        private const val METHOD_CHANNEL = "car_dashboard/bluetooth_classic"
        private const val EVENT_CHANNEL = "car_dashboard/bluetooth_classic/input"
        private const val REQUEST_CODE_BT_PERMISSIONS = 9001

        /** Standard Serial Port Profile UUID for RFCOMM connections. */
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        /** Buffer size for reading from the Bluetooth input stream. */
        private const val READ_BUFFER_SIZE = 1024
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(binaryMessenger, METHOD_CHANNEL)
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var bluetoothSocket: BluetoothSocket? = null
    private var inputThread: Thread? = null

    @Volatile
    private var isConnected: Boolean = false

    /** Pending result waiting for permission grant callback. */
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionAction: String? = null
    private var pendingConnectAddress: String? = null

    // =========================================================================
    // REGISTRATION
    // =========================================================================

    /** Register MethodChannel and EventChannel handlers. Call from [MainActivity]. */
    fun register() {
        methodChannel.setMethodCallHandler(::onMethodCall)

        eventChannel = EventChannel(binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    /** Unregister channels and release resources. */
    fun dispose() {
        isConnected = false
        inputThread?.interrupt()
        inputThread = null
        try {
            bluetoothSocket?.close()
        } catch (_: IOException) {
        }
        bluetoothSocket = null
        methodChannel.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
    }

    // =========================================================================
    // PERMISSION HANDLING
    // =========================================================================

    /** Check if all required Bluetooth permissions are granted. */
    private fun hasBluetoothPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ requires BLUETOOTH_CONNECT and BLUETOOTH_SCAN
            return ContextCompat.checkSelfPermission(
                activity, Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED &&
                    ContextCompat.checkSelfPermission(
                        activity, Manifest.permission.BLUETOOTH_SCAN
                    ) == PackageManager.PERMISSION_GRANTED
        }
        // Pre-Android 12: legacy permissions are normal (auto-granted via manifest)
        return true
    }

    /** Request runtime Bluetooth permissions (Android 12+). */
    private fun requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
                ),
                REQUEST_CODE_BT_PERMISSIONS
            )
        }
    }

    /**
     * Called from [MainActivity.onRequestPermissionsResult] when the user
     * responds to the permission dialog.
     */
    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE_BT_PERMISSIONS) return

        val allGranted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        val result = pendingPermissionResult
        val action = pendingPermissionAction
        val address = pendingConnectAddress

        pendingPermissionResult = null
        pendingPermissionAction = null
        pendingConnectAddress = null

        if (!allGranted) {
            result?.error("PERMISSION_DENIED", "Bluetooth permissions were denied by user", null)
            return
        }

        // Re-execute the original action now that permissions are granted
        when (action) {
            "getBondedDevices" -> if (result != null) getBondedDevicesInternal(result)
            "connect" -> if (result != null && address != null) connectInternal(address, result)
        }
    }

    // =========================================================================
    // METHOD DISPATCH
    // =========================================================================

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBondedDevices" -> getBondedDevices(result)
            "connect" -> {
                val address = call.argument<String>("address")
                if (address == null) {
                    result.error("INVALID_ARGUMENT", "Missing 'address' argument", null)
                } else {
                    connect(address, result)
                }
            }

            "write" -> {
                val data = call.argument<ByteArray>("data")
                if (data == null) {
                    result.error("INVALID_ARGUMENT", "Missing 'data' argument", null)
                } else {
                    write(data, result)
                }
            }

            "disconnect" -> disconnect(result)
            "isConnected" -> result.success(isConnected)
            else -> result.notImplemented()
        }
    }

    // =========================================================================
    // BLUETOOTH OPERATIONS (with permission checks)
    // =========================================================================

    private fun getBondedDevices(result: MethodChannel.Result) {
        if (!hasBluetoothPermissions()) {
            pendingPermissionResult = result
            pendingPermissionAction = "getBondedDevices"
            requestBluetoothPermissions()
            return
        }
        getBondedDevicesInternal(result)
    }

    private fun connect(address: String, result: MethodChannel.Result) {
        if (!hasBluetoothPermissions()) {
            pendingPermissionResult = result
            pendingPermissionAction = "connect"
            pendingConnectAddress = address
            requestBluetoothPermissions()
            return
        }
        connectInternal(address, result)
    }

    // =========================================================================
    // BLUETOOTH OPERATIONS (internal — permissions already verified)
    // =========================================================================

    @Suppress("MissingPermission")
    private fun getBondedDevicesInternal(result: MethodChannel.Result) {
        try {
            val adapter = bluetoothAdapter
            if (adapter == null) {
                result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not available on this device", null)
                return
            }

            val devices = adapter.bondedDevices.map { device ->
                mapOf(
                    "name" to (device.name ?: ""),
                    "address" to device.address
                )
            }
            result.success(devices)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission not granted: ${e.message}", null)
        }
    }

    @Suppress("MissingPermission")
    private fun connectInternal(address: String, result: MethodChannel.Result) {
        // Run connection on a background thread (blocking I/O)
        Thread {
            try {
                // Clean up any existing connection
                closeSocketQuietly()

                val device = bluetoothAdapter?.getRemoteDevice(address)
                if (device == null) {
                    postResult(result) {
                        it.error("DEVICE_NOT_FOUND", "Device with address $address not found", null)
                    }
                    return@Thread
                }

                // Cancel discovery to speed up connection
                bluetoothAdapter?.cancelDiscovery()

                // Create insecure RFCOMM socket (required for most OBD-II / ELM327 dongles)
                val socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()

                bluetoothSocket = socket
                isConnected = true

                // Start reading the input stream
                startInputReader()

                postResult(result) { it.success(true) }
            } catch (e: Exception) {
                isConnected = false
                closeSocketQuietly()
                postResult(result) {
                    it.error("CONNECTION_FAILED", "Failed to connect: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun write(data: ByteArray, result: MethodChannel.Result) {
        try {
            val outputStream = bluetoothSocket?.outputStream
            if (outputStream == null || !isConnected) {
                result.error("NOT_CONNECTED", "No active Bluetooth connection", null)
                return
            }
            outputStream.write(data)
            outputStream.flush()
            result.success(true)
        } catch (e: IOException) {
            result.error("WRITE_FAILED", "Failed to write: ${e.message}", null)
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        try {
            isConnected = false
            inputThread?.interrupt()
            inputThread = null
            closeSocketQuietly()
            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECT_FAILED", "Failed to disconnect: ${e.message}", null)
        }
    }

    // =========================================================================
    // INPUT STREAM READER
    // =========================================================================

    /**
     * Continuously reads from the Bluetooth socket's input stream on a
     * background thread and forwards each chunk to Flutter via [EventChannel].
     */
    private fun startInputReader() {
        inputThread = Thread {
            val buffer = ByteArray(READ_BUFFER_SIZE)
            val inputStream = bluetoothSocket?.inputStream

            while (isConnected && inputStream != null && !Thread.currentThread().isInterrupted) {
                try {
                    val bytesRead = inputStream.read(buffer)
                    if (bytesRead > 0) {
                        val chunk = buffer.copyOf(bytesRead)
                        mainHandler.post { eventSink?.success(chunk) }
                    } else if (bytesRead == -1) {
                        // End of stream — remote device disconnected
                        break
                    }
                } catch (e: IOException) {
                    // Socket closed or read error
                    break
                }
            }

            // Notify Flutter that the stream ended (disconnected)
            if (isConnected) {
                isConnected = false
                mainHandler.post { eventSink?.endOfStream() }
            }
        }
        inputThread?.isDaemon = true
        inputThread?.name = "BtClassicInputReader"
        inputThread?.start()
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    private fun closeSocketQuietly() {
        try {
            bluetoothSocket?.close()
        } catch (_: IOException) {
        }
        bluetoothSocket = null
    }

    /** Post a [MethodChannel.Result] callback on the main thread. */
    private fun postResult(result: MethodChannel.Result, action: (MethodChannel.Result) -> Unit) {
        mainHandler.post { action(result) }
    }
}
