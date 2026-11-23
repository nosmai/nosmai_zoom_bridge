package com.nosmai.zoom;

import android.os.Handler;
import android.os.Looper;
import com.nosmai.effect.api.NosmaiSDK;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.atomic.AtomicBoolean;
import us.zoom.sdk.*;

/** Publishes only the filtered Nosmai camera to Zoom's external source. */
public final class NosmaiZoomSource implements ZoomVideoSDKVideoSource, Runnable {
    static { System.loadLibrary("nosmai_zoom_frames"); }
    private static native int fit(ByteBuffer input, int w, int h, ByteBuffer output, int tw, int th);
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final Set<NosmaiZoomSource> SOURCES = Collections.newSetFromMap(new WeakHashMap<>());
    private static NosmaiZoomSource exportOwner;
    private final Object engine;
    private final ExecutorService worker = Executors.newSingleThreadExecutor(r -> new Thread(r, "NosmaiZoomVideo"));
    private final AtomicBoolean busy = new AtomicBoolean();
    private final NosmaiSDK.FrameCallback callback = this::offer;
    private NosmaiSDK.RenderMode previousMode;
    private ZoomVideoSDKVideoSender sender;
    private boolean sending, closed;
    private int width, height, fps, generation;
    private long nextDue;
    private ByteBuffer input, output;
    private int inputW, inputH, targetW, targetH, frameGeneration;

    private NosmaiZoomSource(Object engine) { this.engine = engine; }

    public static void configure(ZoomVideoSDKSessionContext context, Object engine) {
        NosmaiZoomSource source = new NosmaiZoomSource(engine);
        synchronized (SOURCES) { SOURCES.add(source); }
        context.externalVideoSource = source;
        context.externalVideoSourceDataFormat = ExternalSourceDataFormat.ExternalSourceDataFormat_I420_Full;
    }

    static void detachEngine(Object engine) {
        List<NosmaiZoomSource> sources;
        synchronized (SOURCES) { sources = new ArrayList<>(SOURCES); }
        for (NosmaiZoomSource source : sources) {
            if (source.engine == engine) source.onUninitialized();
        }
    }

    private static int bytes(int w, int h) {
        return w > 0 && h > 0 && w <= 8192 && h <= 8192 && ((w | h) & 1) == 0
                ? w * h * 3 / 2 : 0;
    }

    @Override public synchronized void onInitialize(ZoomVideoSDKVideoSender sender,
            List<ZoomVideoSDKVideoCapability> supported, ZoomVideoSDKVideoCapability suggested) {
        if (closed) return;
        this.sender = sender;
        onPropertyChange(supported, suggested);
    }

    @Override public synchronized void onPropertyChange(List<ZoomVideoSDKVideoCapability> supported,
            ZoomVideoSDKVideoCapability cap) {
        if (cap == null && supported != null && !supported.isEmpty()) cap = supported.get(0);
        width = cap == null ? 0 : cap.getWidth();
        height = cap == null ? 0 : cap.getHeight();
        fps = cap == null ? 0 : cap.getFrame();
        nextDue = 0;
        ++generation;
    }

    @Override public synchronized void onStartSend() {
        if (closed) return;
        sending = true;
        nextDue = 0;
        MAIN.post(this::updateExport);
    }

    @Override public synchronized void onStopSend() {
        sending = false;
        ++generation;
        MAIN.post(this::updateExport);
    }

    @Override public synchronized void onUninitialized() {
        closed = true;
        sender = null;
        onStopSend();
        worker.shutdown();
    }

    // Never change the Nosmai callback from inside a delivered frame.
    private void updateExport() {
        boolean start;
        synchronized (this) { start = sending && !closed; }
        if (start && exportOwner != this) {
            if (exportOwner != null) exportOwner.clearExport();
            previousMode = NosmaiSDK.getRenderMode();
            exportOwner = this;
            NosmaiSDK.setRenderMode(NosmaiSDK.RenderMode.DUAL_OUTPUT);
            NosmaiSDK.setFrameCallback(callback);
        } else if (!start && exportOwner == this) {
            clearExport();
        }
    }

    private void clearExport() {
        NosmaiSDK.setFrameCallback(null);
        if (NosmaiSDK.getRenderMode() == NosmaiSDK.RenderMode.DUAL_OUTPUT)
            NosmaiSDK.setRenderMode(previousMode);
        exportOwner = null;
    }

    private void offer(NosmaiSDK.FrameData frame) {
        if (frame == null || frame.format != 1 || frame.pixelBuffer == null) return;
        int size = bytes(frame.width, frame.height);
        if (size == 0 || frame.pixelBuffer.length < size || !busy.compareAndSet(false, true)) return;
        boolean posted = false;
        try {
            synchronized (this) {
                if (!sending || sender == null || bytes(width, height) == 0 || fps <= 0) return;
                long now = System.nanoTime(), period = 1_000_000_000L / fps;
                if (now + period / 10 < nextDue) return;
                nextDue = Math.max(now, nextDue) + period;
                frameGeneration = generation;
                targetW = width;
                targetH = height;
            }
            inputW = frame.width;
            inputH = frame.height;
            if (input == null || input.capacity() < size) input = ByteBuffer.allocateDirect(size);
            input.clear();
            input.put(frame.pixelBuffer, 0, size).flip();
            worker.execute(this);
            posted = true;
        } catch (RejectedExecutionException ignored) {
            // The session closed while the callback was copying the SDK-owned pixels.
        } finally {
            if (!posted) busy.set(false);
        }
    }

    @Override public void run() {
        try {
            int size = bytes(targetW, targetH);
            ByteBuffer buffer = input;
            int rotation = ZoomVideoSDKVideoSender.ROTATION_ACTION_0;
            if (inputW != targetW || inputH != targetH) {
                if (output == null || output.capacity() < size) output = ByteBuffer.allocateDirect(size);
                int degrees = fit(input, inputW, inputH, output, targetW, targetH);
                if (degrees < 0) return;
                rotation = degrees == 90 ? ZoomVideoSDKVideoSender.ROTATION_ACTION_90 : rotation;
                output.clear();
                output.limit(size);
                buffer = output;
            }
            synchronized (this) {
                if (sending && sender != null && generation == frameGeneration)
                    sender.sendVideoFrame(buffer, targetW, targetH, size, rotation);
            }
        } finally {
            busy.set(false);
        }
    }
}
