package de.devilapi.web2apk.template;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private static final int REQUEST_FILES = 1;
    private static final int MENU_RELOAD = 1;
    private static final int LEGACY_IMMERSIVE_FLAGS = View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;

    private WebView webView;
    private FrameLayout root;
    private ProgressBar progressBar;
    private View errorView;
    private Downloads downloads;

    private int color;
    private int barTextColor;
    private String darkMode;
    private boolean dark;
    private boolean hideSystemBars;
    private boolean immersive;
    private boolean showReload;
    private boolean loadingColor;
    private boolean externalLinks;
    private int orientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;

    /** Host of the configured URL, and of wherever it finally redirected to. */
    private String startHost;
    private String loadedHost;
    private String failedUrl;

    private ValueCallback<Uri[]> filesCallback;
    private View videoView;
    private WebChromeClient.CustomViewCallback videoCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        JSONObject config;
        try {
            config = readConfig();
        } catch (Exception e) {
            throw new RuntimeException("Invalid assets/config.json", e);
        }

        // WebView follows the theme's isLightTheme, so the theme must be set
        // before anything is created. Darkening needs Android 13.
        darkMode = config.optString("darkMode", "off");
        dark = Build.VERSION.SDK_INT >= 33
                && ("always".equals(darkMode) || ("system".equals(darkMode) && systemIsDark()));
        if (dark) {
            setTheme(android.R.style.Theme_Material);
        }
        super.onCreate(savedInstanceState);

        String url = config.optString("url");
        String title = config.optString("title");
        color = Color.parseColor(config.optString("color", "#2196F3"));
        barTextColor = Color.luminance(color) < 0.5f ? Color.WHITE : Color.BLACK;
        boolean fullscreen = config.optBoolean("fullscreen", false);
        showReload = config.optBoolean("reloadButton", false) && !fullscreen;
        hideSystemBars = config.optBoolean("hideSystemBars", false);
        loadingColor = config.optBoolean("loadingColor", false);
        externalLinks = config.optBoolean("externalLinks", false);
        startHost = Uri.parse(url).getHost();

        String wantedOrientation = config.optString("orientation", "auto");
        if ("portrait".equals(wantedOrientation)) {
            orientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
        } else if ("landscape".equals(wantedOrientation)) {
            orientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE;
        }
        setRequestedOrientation(orientation);

        if (config.optBoolean("keepScreenOn", false)) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }

        int darker = Color.rgb(
                (int) (Color.red(color) * 0.8f),
                (int) (Color.green(color) * 0.8f),
                (int) (Color.blue(color) * 0.8f));
        getWindow().setStatusBarColor(darker);

        if (fullscreen) {
            getActionBar().hide();
        } else {
            getActionBar().setBackgroundDrawable(new ColorDrawable(color));
            SpannableString spannable = new SpannableString(title);
            spannable.setSpan(new ForegroundColorSpan(barTextColor), 0, spannable.length(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            getActionBar().setTitle(spannable);
        }

        webView = new WebView(this);
        configureWebView(config);

        root = new FrameLayout(this);
        root.addView(webView);
        if (config.optBoolean("progressBar", false)) {
            progressBar = buildProgressBar();
            root.addView(progressBar);
        }
        if (config.optBoolean("offlinePage", false)) {
            errorView = buildErrorView();
            root.addView(errorView);
        }
        if (loadingColor) {
            getWindow().setBackgroundDrawable(new ColorDrawable(color));
            webView.setBackgroundColor(color);
        }
        // Without decor insets (immersive mode) adjustResize stops working,
        // so make room for the keyboard here.
        root.setOnApplyWindowInsetsListener((view, insets) -> {
            int bottom = immersive && Build.VERSION.SDK_INT >= 30
                    ? insets.getInsets(WindowInsets.Type.ime()).bottom : 0;
            view.setPadding(0, 0, 0, bottom);
            return insets;
        });
        setContentView(root);
        setBarsHidden(hideSystemBars);

        if (savedInstanceState == null) {
            webView.loadUrl(url);
        } else {
            webView.restoreState(savedInstanceState);
        }
    }

    private void configureWebView(JSONObject config) {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        if (config.optBoolean("pinchZoom", false)) {
            settings.setSupportZoom(true);
            settings.setBuiltInZoomControls(true);
            settings.setDisplayZoomControls(false);
        }
        if (Build.VERSION.SDK_INT >= 33) {
            settings.setAlgorithmicDarkeningAllowed(dark);
        }
        if (config.optBoolean("desktopMode", false)) {
            settings.setUseWideViewPort(true);
            settings.setLoadWithOverviewMode(true);
            settings.setUserAgentString(settings.getUserAgentString()
                    .replaceAll("\\(Linux; Android[^)]*\\)", "(X11; Linux x86_64)")
                    .replace(" Mobile", "")
                    .replace("Version/4.0 ", ""));
        }
        String userAgent = config.optString("userAgent").trim();
        if (!userAgent.isEmpty()) {
            settings.setUserAgentString(userAgent);
        }

        webView.setWebViewClient(new Client());
        webView.setWebChromeClient(new ChromeClient());
        downloads = new Downloads(this, webView);
        downloads.attach();
    }

    private boolean systemIsDark() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private ProgressBar buildProgressBar() {
        ProgressBar bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(100);
        bar.setProgressTintList(ColorStateList.valueOf(color));
        bar.setVisibility(View.GONE);
        bar.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(4), Gravity.TOP));
        return bar;
    }

    private View buildErrorView() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setPadding(dp(32), dp(32), dp(32), dp(32));
        layout.setClickable(true);
        layout.setVisibility(View.GONE);
        TypedArray attrs = obtainStyledAttributes(new int[] {android.R.attr.colorBackground});
        layout.setBackgroundColor(attrs.getColor(0, Color.WHITE));
        attrs.recycle();

        TextView title = new TextView(this);
        title.setText("Can't reach this page");
        title.setTextSize(20);
        title.setGravity(Gravity.CENTER);
        layout.addView(title);

        TextView hint = new TextView(this);
        hint.setText("Check your connection and try again.");
        hint.setGravity(Gravity.CENTER);
        hint.setPadding(0, dp(8), 0, dp(24));
        layout.addView(hint);

        Button retry = new Button(this);
        retry.setText("Retry");
        retry.setTextColor(barTextColor);
        retry.setBackgroundTintList(ColorStateList.valueOf(color));
        retry.setOnClickListener(view -> {
            String target = failedUrl;
            if (target != null) {
                webView.loadUrl(target);
            }
        });
        layout.addView(retry, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        return layout;
    }

    private void setBarsHidden(boolean on) {
        immersive = on;
        Window window = getWindow();
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(!on);
            WindowInsetsController controller = window.getInsetsController();
            if (controller == null) {
                return;
            }
            if (on) {
                controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                controller.hide(WindowInsets.Type.systemBars());
            } else {
                controller.show(WindowInsets.Type.systemBars());
            }
        } else {
            window.getDecorView().setSystemUiVisibility(on ? LEGACY_IMMERSIVE_FLAGS : 0);
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        // Before Android 11 the flags are cleared when a dialog or the
        // keyboard takes the focus.
        if (hasFocus && immersive && Build.VERSION.SDK_INT < 30) {
            getWindow().getDecorView().setSystemUiVisibility(LEGACY_IMMERSIVE_FLAGS);
        }
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        if (Build.VERSION.SDK_INT >= 33 && "system".equals(darkMode) && systemIsDark() != dark) {
            recreate();
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        if (!showReload) {
            return false;
        }
        MenuItem item = menu.add(Menu.NONE, MENU_RELOAD, Menu.NONE, "Reload");
        Drawable icon = getDrawable(R.drawable.ic_reload).mutate();
        icon.setTint(barTextColor);
        item.setIcon(icon);
        item.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == MENU_RELOAD) {
            if (failedUrl != null) {
                webView.loadUrl(failedUrl);
            } else {
                webView.reload();
            }
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    /** Whether [host] belongs to [site], ignoring a leading www. */
    private static boolean sameSite(String host, String site) {
        if (host == null || site == null) {
            return false;
        }
        String a = host.startsWith("www.") ? host.substring(4) : host;
        String b = site.startsWith("www.") ? site.substring(4) : site;
        return a.equals(b) || a.endsWith("." + b) || b.endsWith("." + a);
    }

    private boolean openExternally(Uri uri) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
            return true;
        } catch (ActivityNotFoundException e) {
            return false;
        }
    }

    private class Client extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            String scheme = uri.getScheme();
            if (!"http".equals(scheme) && !"https".equals(scheme)) {
                openExternally(uri);
                return true;
            }
            // Until the first page is up, redirects of the start URL stay in
            // the app, and that page's host counts as the app's own.
            if (externalLinks && loadedHost != null && request.isForMainFrame()
                    && !sameSite(uri.getHost(), startHost)
                    && !sameSite(uri.getHost(), loadedHost)) {
                return openExternally(uri);
            }
            return false;
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            failedUrl = null;
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request,
                WebResourceError error) {
            if (errorView != null && request.isForMainFrame()) {
                failedUrl = request.getUrl().toString();
                errorView.setVisibility(View.VISIBLE);
            }
        }

        @Override
        public void onPageCommitVisible(WebView view, String url) {
            if (failedUrl != null) {
                return;
            }
            if (loadedHost == null) {
                loadedHost = Uri.parse(url).getHost();
            }
            if (loadingColor) {
                // Pages without a background of their own must not turn the
                // app color.
                webView.setBackgroundColor(dark ? Color.BLACK : Color.WHITE);
            }
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            downloads.trackNames();
            if (errorView != null && failedUrl == null) {
                errorView.setVisibility(View.GONE);
            }
        }
    }

    private class ChromeClient extends WebChromeClient {
        @Override
        public void onProgressChanged(WebView view, int newProgress) {
            if (progressBar != null) {
                progressBar.setProgress(newProgress);
                progressBar.setVisibility(newProgress < 100 ? View.VISIBLE : View.GONE);
            }
        }

        @Override
        public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                FileChooserParams params) {
            if (filesCallback != null) {
                filesCallback.onReceiveValue(null);
            }
            filesCallback = callback;
            Intent intent = params.createIntent();
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE,
                    params.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE);
            try {
                startActivityForResult(intent, REQUEST_FILES);
                return true;
            } catch (ActivityNotFoundException e) {
                filesCallback = null;
                return false;
            }
        }

        @Override
        public void onShowCustomView(View view, CustomViewCallback callback) {
            if (videoView != null) {
                callback.onCustomViewHidden();
                return;
            }
            videoView = view;
            videoCallback = callback;
            ((ViewGroup) getWindow().getDecorView()).addView(view, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            setBarsHidden(true);
            // A locked app must still be able to play landscape video.
            setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_USER);
        }

        @Override
        public void onHideCustomView() {
            if (videoView == null) {
                return;
            }
            ((ViewGroup) getWindow().getDecorView()).removeView(videoView);
            videoView = null;
            setBarsHidden(hideSystemBars);
            setRequestedOrientation(orientation);
            videoCallback.onCustomViewHidden();
            videoCallback = null;
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_FILES || filesCallback == null) {
            super.onActivityResult(requestCode, resultCode, data);
            return;
        }
        filesCallback.onReceiveValue(pickedFiles(resultCode, data));
        filesCallback = null;
    }

    private static Uri[] pickedFiles(int resultCode, Intent data) {
        if (resultCode != RESULT_OK || data == null) {
            return null;
        }
        List<Uri> uris = new ArrayList<>();
        ClipData clip = data.getClipData();
        if (clip != null) {
            for (int i = 0; i < clip.getItemCount(); i++) {
                uris.add(clip.getItemAt(i).getUri());
            }
        } else if (data.getData() != null) {
            uris.add(data.getData());
        }
        return uris.isEmpty() ? null : uris.toArray(new Uri[0]);
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
        if (videoView != null) {
            webView.getWebChromeClient().onHideCustomView();
        } else if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
