package com.example.digital_memory
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Protect private routes, transition frames and the Android recents
        // snapshot. This also intentionally blocks screenshots of the app.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
