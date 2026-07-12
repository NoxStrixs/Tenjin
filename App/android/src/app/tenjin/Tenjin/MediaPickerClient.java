package app.tenjin.Tenjin;

import android.app.Activity;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

// Launches the appropriate Android picker for media/import and copies the
// chosen content:// URI into the app's cache (content URIs are not persistently
// readable), then hands the sandbox path back to C++ via JNI. Result routing
// goes through the C++ ActivityResultListener, which calls deliverResult().
//
// Photos use the modern Photo Picker (ACTION_PICK_IMAGES, API 33+; SAF fallback
// below that). Files use SAF ACTION_OPEN_DOCUMENT. Camera uses
// ACTION_IMAGE_CAPTURE into a cache file exposed via FileProvider.
public final class MediaPickerClient {

    // Request codes distinguish the flows in onActivityResult.
    public static final int REQ_PHOTOS = 3001;
    public static final int REQ_FILES  = 3002;
    public static final int REQ_CAMERA = 3003;
    public static final int REQ_IMPORT = 3004;

    // Set when a camera capture is in flight: the output URI we asked the camera
    // to write to (camera result Intent has no data).
    private static Uri sPendingCameraUri = null;

    // Implemented in C++ (DocumentPickerService_android.cpp) via RegisterNatives.
    // kind: 0 = media (-> mediaPicked), 1 = import (-> documentPicked).
    private static native void deliverResult(String path, int kind);
    private static native void deliverCancelled();

    public static void pickPhotos(Activity a) {
        if (a == null) { deliverCancelled(); return; }
        Intent intent;
        if (Build.VERSION.SDK_INT >= 33) {
            intent = new Intent(MediaStore.ACTION_PICK_IMAGES);
            intent.setType("image/*");
        } else {
            // SAF fallback below API 33.
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("image/*");
        }
        a.startActivityForResult(intent, REQ_PHOTOS);
    }

    public static void pickFiles(Activity a) {
        if (a == null) { deliverCancelled(); return; }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        a.startActivityForResult(intent, REQ_FILES);
    }

    public static void pickCamera(Activity a) {
        if (a == null) { deliverCancelled(); return; }
        try {
            File out = File.createTempFile("tenjin-cam-", ".jpg", a.getCacheDir());
            Uri uri = androidx.core.content.FileProvider.getUriForFile(
                a, a.getPackageName() + ".qtprovider", out);
            sPendingCameraUri = uri;
            Intent intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            intent.putExtra(MediaStore.EXTRA_OUTPUT, uri);
            intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            a.startActivityForResult(intent, REQ_CAMERA);
        } catch (Exception e) {
            deliverCancelled();
        }
    }

    public static void pickImport(Activity a) {
        if (a == null) { deliverCancelled(); return; }
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        // JSON collection or Anki .apkg (a zip). Broad type + extension filter.
        intent.setType("*/*");
        a.startActivityForResult(intent, REQ_IMPORT);
    }

    // Called from C++ onActivityResult routing.
    public static void handleResult(Context ctx, int requestCode, int resultCode, Intent data) {
        if (resultCode != Activity.RESULT_OK) {
            sPendingCameraUri = null;
            deliverCancelled();
            return;
        }
        try {
            if (requestCode == REQ_CAMERA) {
                Uri uri = sPendingCameraUri;
                sPendingCameraUri = null;
                if (uri == null) { deliverCancelled(); return; }
                // Camera already wrote to our FileProvider file; copy to a
                // stable cache path and return it.
                String path = copyToCache(ctx, uri, "jpg");
                emit(path, 0);
                return;
            }
            Uri uri = (data != null) ? data.getData() : null;
            if (uri == null) { deliverCancelled(); return; }
            int kind = (requestCode == REQ_IMPORT) ? 1 : 0;
            String ext = guessExtension(ctx, uri);
            String path = copyToCache(ctx, uri, ext);
            emit(path, kind);
        } catch (Exception e) {
            deliverCancelled();
        }
    }

    private static void emit(String path, int kind) {
        if (path == null) deliverCancelled();
        else deliverResult(path, kind);
    }

    // Copy a content:// URI into the app cache; returns the absolute file path.
    private static String copyToCache(Context ctx, Uri uri, String ext) {
        try {
            String name = "tenjin-" + System.currentTimeMillis()
                + (ext != null && !ext.isEmpty() ? "." + ext : "");
            File out = new File(ctx.getCacheDir(), name);
            try (InputStream in = ctx.getContentResolver().openInputStream(uri);
                 OutputStream os = new FileOutputStream(out)) {
                if (in == null) return null;
                byte[] buf = new byte[65536];
                int n;
                while ((n = in.read(buf)) > 0) os.write(buf, 0, n);
            }
            return out.getAbsolutePath();
        } catch (Exception e) {
            return null;
        }
    }

    private static String guessExtension(Context ctx, Uri uri) {
        String type = ctx.getContentResolver().getType(uri);
        if (type == null) return "";
        int slash = type.indexOf('/');
        if (slash >= 0 && slash + 1 < type.length()) {
            String sub = type.substring(slash + 1);
            // Normalize a few common subtypes.
            if (sub.equals("jpeg")) return "jpg";
            if (sub.equals("quicktime")) return "mov";
            if (sub.contains("+")) sub = sub.substring(0, sub.indexOf('+'));
            return sub;
        }
        return "";
    }
}
