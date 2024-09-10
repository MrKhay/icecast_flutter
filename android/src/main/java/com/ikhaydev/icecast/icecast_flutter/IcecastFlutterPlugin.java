package com.ikhaydev.icecast.icecast_flutter;

import static io.flutter.util.PathUtils.getFilesDir;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.arthenica.mobileffmpeg.FFmpeg;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * IcecastFlutterPlugin
 */
public class IcecastFlutterPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private Context context;
    private Activity activity;
    private MethodChannel channel;

    private String SAMPLE_RATE = "44100";  // Sample rate in Hz
    private String BIT_RATE = "128";  // Bit rate in kbps
    private String NUM_CHANNELS = "2";  // Channel
    private String ICECAST_PASSWORD;
    private String ICECAST_USERNAME;
    private String ICECAST_PORT;
    private String ICECAST_MOUNT;
    private String ICECAST_SERVER_ADDRESS;
    private FileOutputStream fos1;

    private Thread streamingThread;

    private String pipePath;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "icecast_flutter");
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
    }

    void logError(String msg) {
        // Create a map to hold error information
        Map<String, String> errorInfo = new HashMap<>();
        errorInfo.put("error", msg);  // Key should match what Dart expects
        channel.invokeMethod("onError", errorInfo);
    }


    private void startStreaming() {
        try {

            // Get the app's private storage directory and create a named pipe
            File storageDir = new File(getFilesDir(context));
            pipePath = new File(storageDir, "audio_pipe_one").getAbsolutePath();
            createNamedPipe();


            // Start streaming thread

            String[] command = {
                    "-thread_queue_size", "812",
                    "-f", "s16le",  // PCM 16-bit
                    "-ar", SAMPLE_RATE,  // Set the sample rate
                    "-ac", NUM_CHANNELS,  // Set the channel count
                    "-i", pipePath,  // Input from the named pipe
                    "-c:a", "libopus",  // Use the Opus codec for output
                    "-b:a", BIT_RATE + "k",  // Set the bitrate for Opus
                    "-application", "audio",  // Set the Opus application type (audio)
                    "-f", "opus",  // Set the output format to Opus
                    "icecast://" + ICECAST_USERNAME + ":" + ICECAST_PASSWORD + "@" + ICECAST_SERVER_ADDRESS + ":" + ICECAST_PORT + ICECAST_MOUNT
            };


            // Run the FFmpeg process
            try {
                long id = FFmpeg.executeAsync(command, new ExecuteCallback());

            } catch (Exception e) {
                Log.i("FFmpeg", "Executing FFmpeg command");
            }

            fos1 = new FileOutputStream(pipePath);
            streamingThread.start();

        } catch (Exception e) {
            Log.e("FFmpeg", "Streaming failed" + e.getMessage());
        }
    }


    private String stopStreaming() {
        try {
            if (streamingThread != null) {
                streamingThread.interrupt();
                streamingThread = null;

            }
            FFmpeg.cancel();
            if (fos1 != null) {
                fos1.close();
                fos1 = null;
            }
            closeAndDeleteNamedPipes();
            return null;
        } catch (Exception e) {
            logError(e.getMessage());
            return "Stopping stream failed: " + e.getMessage();
        }
    }

    private String writeToNamedPipe1(byte[] chunk) {
        try {
            if (fos1 != null) {
                fos1.write(chunk);
//                logByteArray(chunk);
                fos1.flush(); // Ensure data is written
            }
            return null;
        } catch (IOException e) {
            Log.i("FFmpeg", "(1) " + e.getMessage());
            return e.getMessage();
        }
    }


    private void logByteArray(byte[] byteArray) {
        StringBuilder unsignedData = new StringBuilder("Unsigned bytes: ");

        for (byte b : byteArray) {
            unsignedData.append(Byte.toUnsignedInt(b)).append(" ");
        }

        Log.i("FFmpeg", unsignedData.toString());
    }


    private void createNamedPipe() {
        File pipe = new File(pipePath);
        if (!pipe.exists()) {
            try {
                Runtime.getRuntime().exec("mkfifo " + pipePath).waitFor();
            } catch (IOException | InterruptedException e) {
                Log.i("FFmpeg", "(1) " + e.getMessage());
                e.printStackTrace();
            }
        }
    }


    private void closeAndDeleteNamedPipes() {
        deletePipe(pipePath);
    }

    private void deletePipe(String path) {
        File pipe = new File(path);
        if (pipe.exists()) {
            try {
                pipe.delete();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }


    public byte[] convertIntListToUnsignedByteArray(ArrayList<Integer> intList) {
        // Create a ByteBuffer with capacity for 2 bytes per sample
        ByteBuffer byteBuffer = ByteBuffer.allocate(intList.size() * 2);
        byteBuffer.order(ByteOrder.LITTLE_ENDIAN); // Set to little-endian

        // Convert each Integer PCM sample to bytes
        for (Integer sample : intList) {
            // Ensure sample is within the valid range for 16-bit PCM
            if (sample < -32768 || sample > 32767) {
                byteBuffer.putShort((short) 0); // add silence
                continue;
            }

            // Write the sample as a short value (2 bytes)
            byteBuffer.putShort(sample.shortValue());
        }

        // Return the underlying byte array from the ByteBuffer
        return byteBuffer.array();
    }


    private class ExecuteCallback implements com.arthenica.mobileffmpeg.ExecuteCallback {
        @Override
        public void apply(long executionId, int returnCode) {
            // Handle completion
            if (returnCode == 0) {
                Log.i("FFmpeg", "Streaming completed successfully");
                channel.invokeMethod("onComplete", "Streaming completed successfully");
            } else {
                logError("Connection to Icecast failed");
                Log.e("FFmpeg", "Error in streaming with return code: " + returnCode);
            }
        }


    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "startStreaming":
                BIT_RATE = call.argument("bitrate");
                NUM_CHANNELS = call.argument("numChannels");
                SAMPLE_RATE = call.argument("sampleRate");
                ICECAST_USERNAME = call.argument("userName");
                ICECAST_MOUNT = call.argument("mount");
                ICECAST_PASSWORD = call.argument("password");
                ICECAST_PORT = call.argument("port");
                ICECAST_SERVER_ADDRESS = call.argument("serverAddress");
                startStreaming();
                result.success(null);
                break;
            case "stopStreaming":
                String errorMsg = stopStreaming();
                result.success(errorMsg);
                break;
            case "writeToPipe":
                java.util.ArrayList<Integer> chunk1 = call.argument("chunk");
                String pipe1Error = writeToNamedPipe1(convertIntListToUnsignedByteArray(chunk1));
                result.success(pipe1Error);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }
}
