package com.ikhaydev.icecast.icecast_flutter;

import static androidx.core.content.ContextCompat.getSystemService;
import static io.flutter.util.PathUtils.getFilesDir;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.util.Log;

import androidx.annotation.NonNull;

import com.arthenica.mobileffmpeg.FFmpeg;
import com.arthenica.mobileffmpeg.FFprobe;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

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
    private FileOutputStream fos2;

    private Thread streamingThread;

    private String pipePath1;
    private String pipePath2;

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
            pipePath1 = new File(storageDir, "audio_pipe_one").getAbsolutePath();
            pipePath2 = new File(storageDir, "audio_pipe_two").getAbsolutePath();
            createNamedPipe1();
            createNamedPipe2();

            // Initialize Pipe 1
            new Thread(() -> {
                try {
                    fos1 = new FileOutputStream(pipePath1);
                } catch (FileNotFoundException e) {
                    Log.e("FFmpeg", "Failed to open output stream 1", e);
                }
            }).start();
            // Initialize Pipe 2
            new Thread(() -> {
                try {
                    fos2 = new FileOutputStream(pipePath2);
                    writeSilenceToNamedPipe2(fos2);
                } catch (FileNotFoundException e) {
                    Log.e("FFmpeg", "Failed to open output stream 2", e);
                }
            }).start();

            // Start streaming thread
            streamingThread = new Thread(() -> {
                String[] command = {
                        "-fflags", "nobuffer",
                        "-thread_queue_size", "512",
                        "-f", "s16le", "-ar", SAMPLE_RATE, "-ac", NUM_CHANNELS,
                        "-i", pipePath1,  // Mic audio
                        "-thread_queue_size", "512",
                        "-f", "s16le", "-ar", SAMPLE_RATE, "-ac", NUM_CHANNELS,
                        "-i", pipePath2,  // Music audio

                        // Mix the two inputs, ensuring silence when one is empty
                        "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=longest:dropout_transition=0",

                        "-c:a", "libmp3lame", "-b:a", BIT_RATE + "k",
                        "-f", "mp3",
                        "icecast://" + ICECAST_USERNAME + ":" + ICECAST_PASSWORD + "@" + ICECAST_SERVER_ADDRESS + ":" + ICECAST_PORT + ICECAST_MOUNT,
                        "-re",  // Real-time input
                        "-loglevel", "verbose",
                };





                // Run the FFmpeg process
                try {
                    long id = FFmpeg.executeAsync(command, new ExecuteCallback());
                } catch (Exception e) {
                    Log.i("FFmpeg", "Executing FFmpeg command");
                }

            });

            streamingThread.start();
        } catch (Exception e) {
            Log.e("FFmpeg", "Streaming failed" + e.getMessage());
        }
    }

    private void writeSilenceToNamedPipe2(FileOutputStream fos) {
        byte[] silence = new byte[Integer.parseInt(SAMPLE_RATE) * Integer.parseInt(NUM_CHANNELS) * 10]; // 2 seconds
        try {
            fos.write(silence);
            fos.flush(); // Ensure data is written to the pipe
        } catch (IOException e) {
            Log.e("FFmpeg", "Error writing continuous silence to pipe2: " + e.getMessage());
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
            if (fos2 != null) {
                fos2.close();
                fos2 = null;
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

    private String writeToNamedPipe2(byte[] chunk) {
        try {
            if (fos2 != null) {
                fos2.write(chunk);
//                logByteArray(chunk);
                fos2.flush(); // Ensure data is written
            }
            return null;
        } catch (IOException e) {
            Log.i("FFmpeg", "(2) " + e.getMessage());
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


    private void createNamedPipe1() {
        File pipe = new File(pipePath1);
        if (!pipe.exists()) {
            try {
                Runtime.getRuntime().exec("mkfifo " + pipePath1).waitFor();
            } catch (IOException | InterruptedException e) {
                Log.i("FFmpeg", "(1) " + e.getMessage());
                e.printStackTrace();
            }
        }
    }

    private void createNamedPipe2() {
        File pipe = new File(pipePath2);
        if (!pipe.exists()) {
            try {
                Runtime.getRuntime().exec("mkfifo " + pipePath2).waitFor();
            } catch (IOException | InterruptedException e) {
                Log.i("FFmpeg", "(2) " + e.getMessage());
                e.printStackTrace();
            }
        }
    }

    private void closeAndDeleteNamedPipes() {
        deletePipe(pipePath1);
        deletePipe(pipePath2);
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
            case "writeToPipe1":
                java.util.ArrayList<Integer> chunk1 = call.argument("chunk");
                String pipe1Error = writeToNamedPipe1(convertIntListToUnsignedByteArray(chunk1));
                result.success(pipe1Error);
                break;
            case "writeToPipe2":
                java.util.ArrayList<Integer> chunk2 = call.argument("chunk");
                String pipe2Error = writeToNamedPipe2(convertIntListToUnsignedByteArray(chunk2));
                result.success(pipe2Error);
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
