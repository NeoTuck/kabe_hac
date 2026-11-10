package com.mustafasenoglu.hac_umre_sesli_rehber

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : AudioServiceActivity() {
    private val COMPASS_CHANNEL = "com.mustafasenoglu.hac_umre_sesli_rehber/compass"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, COMPASS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var sensorManager: SensorManager? = null
                private var sensorListener: SensorEventListener? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                        ?: sensorManager?.getDefaultSensor(Sensor.TYPE_ORIENTATION)

                    if (rotationSensor == null) {
                        events?.error("SENSOR_UNAVAILABLE", "Pusula sensörü bulunamadı", null)
                        return
                    }

                    sensorListener = object : SensorEventListener {
                        private val rotationMatrix = FloatArray(9)
                        private val orientationAngles = FloatArray(3)

                        override fun onSensorChanged(event: SensorEvent?) {
                            if (event == null) return
                            if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                                SensorManager.getOrientation(rotationMatrix, orientationAngles)
                                val azimuthRad = orientationAngles[0]
                                var azimuthDeg = Math.toDegrees(azimuthRad.toDouble())
                                azimuthDeg = (azimuthDeg + 360) % 360
                                events?.success(azimuthDeg)
                            } else if (event.sensor.type == Sensor.TYPE_ORIENTATION) {
                                val azimuth = (event.values[0].toDouble() + 360) % 360
                                events?.success(azimuth)
                            }
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                    }

                    sensorManager?.registerListener(
                        sensorListener,
                        rotationSensor,
                        SensorManager.SENSOR_DELAY_UI
                    )
                }

                override fun onCancel(arguments: Any?) {
                    sensorListener?.let { sensorManager?.unregisterListener(it) }
                    sensorListener = null
                    sensorManager = null
                }
            })
    }
}
