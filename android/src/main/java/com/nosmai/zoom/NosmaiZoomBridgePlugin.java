package com.nosmai.zoom;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/** The external camera source belongs to a Zoom session, not the Flutter UI. */
public final class NosmaiZoomBridgePlugin implements FlutterPlugin {
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {}
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        NosmaiZoomSource.detachEngine(binding.getBinaryMessenger());
    }
}
