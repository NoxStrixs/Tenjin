package app.tenjin.Tenjin;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;

// Storage Access Framework helper for cloud sync. The user picks a folder once
// (typically inside Google Drive, but any DocumentsProvider works); we persist
// read/write permission on that tree URI and read/write snapshot files there.
//
// SAF exposes a tree URI, not a filesystem path, so C++ writes a local file and
// calls pushFile() to copy it into the tree; pullFile() copies the other way.
public final class CloudSyncClient {

    private static final String PREFS = "tenjin_cloud_sync";
    private static final String KEY_TREE = "tree_uri";
    public  static final int REQ_PICK_TREE = 4001;

    private static Uri sTree = null;

    private static SharedPreferences prefs(Context ctx) {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static void init(Context ctx) {
        String s = prefs(ctx).getString(KEY_TREE, null);
        if (s != null) sTree = Uri.parse(s);
    }

    public static boolean hasTree(Context ctx) {
        if (sTree == null) init(ctx);
        if (sTree == null) return false;
        // Verify we still hold the persisted permission.
        for (android.content.UriPermission p : ctx.getContentResolver().getPersistedUriPermissions()) {
            if (p.getUri().equals(sTree) && p.isWritePermission()) return true;
        }
        return false;
    }

    public static String treeLabel(Context ctx) {
        if (!hasTree(ctx)) return "";
        try {
            Uri docUri = DocumentsContract.buildDocumentUriUsingTree(
                    sTree, DocumentsContract.getTreeDocumentId(sTree));
            Cursor c = ctx.getContentResolver().query(docUri,
                    new String[]{DocumentsContract.Document.COLUMN_DISPLAY_NAME},
                    null, null, null);
            if (c != null) {
                try { if (c.moveToFirst()) return c.getString(0); }
                finally { c.close(); }
            }
        } catch (Exception ignored) {}
        return "";
    }

    // Launch the system folder picker. Result arrives in the C++
    // ActivityResultListener under REQ_PICK_TREE.
    public static void pickTree(Activity act) {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                 | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                 | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        act.startActivityForResult(i, REQ_PICK_TREE);
    }

    // Called from the activity result: persist the granted tree.
    public static void saveTree(Context ctx, Uri uri) {
        if (uri == null) return;
        ctx.getContentResolver().takePersistableUriPermission(uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        sTree = uri;
        prefs(ctx).edit().putString(KEY_TREE, uri.toString()).apply();
    }

    // Copy a local file into the tree, replacing any same-named document.
    public static boolean pushFile(Context ctx, String localPath, String displayName) {
        if (!hasTree(ctx)) return false;
        try {
            ContentResolver cr = ctx.getContentResolver();
            Uri parent = DocumentsContract.buildDocumentUriUsingTree(
                    sTree, DocumentsContract.getTreeDocumentId(sTree));
            Uri existing = findChild(ctx, displayName);
            if (existing != null) DocumentsContract.deleteDocument(cr, existing);
            Uri target = DocumentsContract.createDocument(cr, parent,
                    "application/json", displayName);
            if (target == null) return false;
            InputStream in = new FileInputStream(localPath);
            OutputStream out = cr.openOutputStream(target);
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            out.flush(); out.close(); in.close();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // Copy a document out of the tree to a local path.
    public static boolean pullFile(Context ctx, String displayName, String localPath) {
        if (!hasTree(ctx)) return false;
        try {
            Uri child = findChild(ctx, displayName);
            if (child == null) return false;
            InputStream in = ctx.getContentResolver().openInputStream(child);
            OutputStream out = new FileOutputStream(localPath);
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            out.flush(); out.close(); in.close();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // "name|size|lastModifiedMillis" per snapshot, newest first.
    public static String[] listSnapshots(Context ctx) {
        ArrayList<String> out = new ArrayList<>();
        if (!hasTree(ctx)) return new String[0];
        try {
            Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(
                    sTree, DocumentsContract.getTreeDocumentId(sTree));
            Cursor c = ctx.getContentResolver().query(children, new String[]{
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED}, null, null, null);
            if (c != null) {
                try {
                    while (c.moveToNext()) {
                        String name = c.getString(0);
                        if (name == null || !name.startsWith("tenjin-") || !name.endsWith(".json"))
                            continue;
                        out.add(name + "|" + c.getLong(1) + "|" + c.getLong(2));
                    }
                } finally { c.close(); }
            }
        } catch (Exception ignored) {}
        return out.toArray(new String[0]);
    }

    private static Uri findChild(Context ctx, String displayName) {
        try {
            Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(
                    sTree, DocumentsContract.getTreeDocumentId(sTree));
            Cursor c = ctx.getContentResolver().query(children, new String[]{
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME}, null, null, null);
            if (c != null) {
                try {
                    while (c.moveToNext()) {
                        if (displayName.equals(c.getString(1)))
                            return DocumentsContract.buildDocumentUriUsingTree(sTree, c.getString(0));
                    }
                } finally { c.close(); }
            }
        } catch (Exception ignored) {}
        return null;
    }
}
