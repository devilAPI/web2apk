package de.devilapi.web2apk.template;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.ActivityNotFoundException;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.URLUtil;
import android.webkit.WebView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.OutputStream;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * Saves what the website downloads to the Downloads folder. No permission is
 * needed from Android 10 on; older versions hand http(s) downloads to the
 * browser.
 */
final class Downloads {
    private static final String BRIDGE = "web2apkDownloads";

    /** Remembers the download attribute, which Android does not pass on. */
    private static final String TRACK_NAMES = "(() => {"
            + "  if (window.web2apkTracked) return;"
            + "  window.web2apkTracked = true;"
            + "  const remember = a => { if (a && a.download) window.web2apkName = a.download; };"
            + "  document.addEventListener('click',"
            + "    e => remember(e.target.closest && e.target.closest('a')), true);"
            + "  const click = HTMLAnchorElement.prototype.click;"
            + "  HTMLAnchorElement.prototype.click = function () {"
            + "    remember(this);"
            + "    return click.call(this);"
            + "  };"
            + "})()";

    private final Activity activity;
    private final WebView webView;

    /** One per blob download, so a page cannot write files unprompted. */
    private final Set<String> tokens = Collections.synchronizedSet(new HashSet<>());

    Downloads(Activity activity, WebView webView) {
        this.activity = activity;
        this.webView = webView;
    }

    void attach() {
        webView.addJavascriptInterface(this, BRIDGE);
        webView.setDownloadListener((url, userAgent, disposition, mimeType, length) -> {
            String name = fileName(url, disposition, mimeType);
            if (url.startsWith("blob:") || url.startsWith("data:")) {
                readInPage(url, name);
            } else if (Build.VERSION.SDK_INT >= 29) {
                enqueue(url, userAgent, mimeType, name);
            } else {
                openInBrowser(url);
            }
        });
    }

    /** Call for every loaded page. */
    void trackNames() {
        webView.evaluateJavascript(TRACK_NAMES, null);
    }

    private static String fileName(String url, String disposition, String mimeType) {
        String name = URLUtil.guessFileName(url, disposition, mimeType).replaceAll("[/\\\\]", "_");
        return name.replace(".", "").isEmpty() ? "download" : name;
    }

    private void enqueue(String url, String userAgent, String mimeType, String name) {
        try {
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
            request.setMimeType(mimeType);
            String cookies = CookieManager.getInstance().getCookie(url);
            if (cookies != null) {
                request.addRequestHeader("Cookie", cookies);
            }
            request.addRequestHeader("User-Agent", userAgent);
            request.setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name);
            DownloadManager manager =
                    (DownloadManager) activity.getSystemService(Context.DOWNLOAD_SERVICE);
            manager.enqueue(request);
            toast("Downloading " + name);
        } catch (RuntimeException e) {
            toast("Download failed");
        }
    }

    private void openInBrowser(String url) {
        try {
            activity.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (ActivityNotFoundException e) {
            toast("Download failed");
        }
    }

    /** blob: and data: URLs exist only inside the page, so read them there. */
    private void readInPage(String url, String name) {
        if (Build.VERSION.SDK_INT < 29) {
            toast("This download needs Android 10 or newer");
            return;
        }
        String token = UUID.randomUUID().toString();
        tokens.add(token);
        String script = "fetch(" + JSONObject.quote(url) + ")"
                + ".then(r => r.blob())"
                + ".then(b => new Promise((ok, fail) => {"
                + "  const f = new FileReader();"
                + "  f.onload = () => ok(f.result);"
                + "  f.onerror = fail;"
                + "  f.readAsDataURL(b);"
                + "}))"
                + ".then(d => " + BRIDGE + ".save(" + JSONObject.quote(token) + ", d, "
                + "window.web2apkName || " + JSONObject.quote(name) + "))"
                + ".catch(() => " + BRIDGE + ".failed(" + JSONObject.quote(token) + "))";
        webView.evaluateJavascript(script, null);
    }

    @JavascriptInterface
    public void failed(String token) {
        if (tokens.remove(token)) {
            toast("Download failed");
        }
    }

    @JavascriptInterface
    public void save(String token, String dataUrl, String name) {
        if (!tokens.remove(token) || Build.VERSION.SDK_INT < 29) {
            return;
        }
        try {
            int comma = dataUrl.indexOf(',');
            String header = dataUrl.substring("data:".length(), comma);
            int semicolon = header.indexOf(';');
            String mimeType = semicolon < 0 ? header : header.substring(0, semicolon);
            byte[] bytes = Base64.decode(dataUrl.substring(comma + 1), Base64.DEFAULT);

            ContentValues values = new ContentValues();
            values.put(MediaStore.Downloads.DISPLAY_NAME, name.replaceAll("[/\\\\]", "_"));
            values.put(MediaStore.Downloads.MIME_TYPE,
                    mimeType.isEmpty() ? "application/octet-stream" : mimeType);
            values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
            ContentResolver resolver = activity.getContentResolver();
            Uri uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            try (OutputStream out = resolver.openOutputStream(uri)) {
                out.write(bytes);
            }
            toast("Saved " + name + " to Downloads");
        } catch (Exception | OutOfMemoryError e) {
            toast("Download failed");
        }
    }

    private void toast(String message) {
        activity.runOnUiThread(
                () -> Toast.makeText(activity, message, Toast.LENGTH_LONG).show());
    }
}
