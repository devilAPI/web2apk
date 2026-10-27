package de.devilapi.web2apk.template;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

public class MainActivity extends Activity {
    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        JSONObject config;
        try {
            config = readConfig();
        } catch (Exception e) {
            throw new RuntimeException("Invalid assets/config.json", e);
        }
        String url = config.optString("url");
        String title = config.optString("title");
        int color = Color.parseColor(config.optString("color", "#2196F3"));

        int darker = Color.rgb(
                (int) (Color.red(color) * 0.8f),
                (int) (Color.green(color) * 0.8f),
                (int) (Color.blue(color) * 0.8f));
        getWindow().setStatusBarColor(darker);

        if (config.optBoolean("fullscreen", false)) {
            getActionBar().hide();
        } else {
            getActionBar().setBackgroundDrawable(new ColorDrawable(color));
            SpannableString spannable = new SpannableString(title);
            int textColor = Color.luminance(color) < 0.5f ? Color.WHITE : Color.BLACK;
            spannable.setSpan(new ForegroundColorSpan(textColor), 0, spannable.length(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            getActionBar().setTitle(spannable);
        }

        webView = new WebView(this);
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, android.webkit.WebResourceRequest request) {
                Uri uri = request.getUrl();
                String scheme = uri.getScheme();
                if ("http".equals(scheme) || "https".equals(scheme)) {
                    return false;
                }
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, uri));
                } catch (ActivityNotFoundException ignored) {
                }
                return true;
            }
        });
        setContentView(webView);

        if (savedInstanceState == null) {
            webView.loadUrl(url);
        } else {
            webView.restoreState(savedInstanceState);
        }
    }

    private JSONObject readConfig() throws Exception {
        try (InputStream in = getAssets().open("config.json")) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[1024];
            int n;
            while ((n = in.read(buf)) > 0) {
                out.write(buf, 0, n);
            }
            return new JSONObject(out.toString("UTF-8"));
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        webView.saveState(outState);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
