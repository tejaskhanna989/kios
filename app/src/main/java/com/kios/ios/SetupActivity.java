package com.kios.ios;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Set up: bring iOS 12 in from Apple (the app downloads the IPSW from Apple's servers and builds
 * the disk on this phone), or from a file picked here.
 */
public class SetupActivity extends Activity {
    private static final int PICK = 1;
    private LinearLayout box;
    private TextView status;
    private ProgressBar bar;
    private volatile boolean busy;
    private SetupScreen fromApple;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        DevNight.apply(this);
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(Color.BLACK);
        scroll.setFitsSystemWindows(true);
        box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(56, 72, 56, 56);
        scroll.addView(box);
        setContentView(scroll);
        show();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!busy) {
            show();                     // a file may have arrived over adb meanwhile
        }
    }

    private TextView text(String s, float size, int color) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(size);
        t.setTextColor(color);
        t.setPadding(0, 0, 0, 28);
        box.addView(t);
        return t;
    }

    private Button button(String s, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(s);
        b.setAllCaps(false);
        b.setOnClickListener(l);
        box.addView(b);
        return b;
    }

    /** The notice of a record not seen yet (RecordNotice), but the one a failed step or import shows under its line. */
    private RecordNotice notice;
    /** The record of the last import that failed, shown under its status line. */
    private volatile String importRecord;

    private void show() {
        box.removeAllViews();
        // the title, and Logs beside it: there on a fresh app too, where a failed first setup has nothing else to show
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        head.setPadding(0, 0, 0, 28);
        TextView title = new TextView(this);
        title.setText("Set up");
        title.setTextSize(26);
        title.setTextColor(Color.WHITE);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        head.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        Button logs = new Button(this);
        logs.setText("Logs");
        logs.setAllCaps(false);
        logs.setOnClickListener(v -> startActivity(new Intent(this, LogsActivity.class)));
        head.addView(logs, new LinearLayout.LayoutParams(-2, -2));
        box.addView(head);
        if (notice == null) {
            notice = new RecordNotice(this, () -> {
                SetupService.State s = SetupService.state;
                return s.error != null && s.record != null ? s.record : importRecord;
            });
        }
        View n = notice.view();
        if (n.getParent() instanceof android.view.ViewGroup) {
            ((android.view.ViewGroup) n.getParent()).removeView(n);
        }
        LinearLayout.LayoutParams nlp = new LinearLayout.LayoutParams(-1, -2);
        nlp.bottomMargin = 28;
        box.addView(n, nlp);
        if (Installer.installed(this)) {
            text("iOS 12 is set up on this phone. Importing or installing again replaces it: this iPhone's settings, apps and saves go.",
                    15, 0xffbbbbbb);
        }
        // Apple's files, the phone's own setup (PhoneSetup) downloads iOS 12 from Apple and builds its disk on the phone
        if (fromApple == null) {
            fromApple = new SetupScreen(this);
        }
        box.addView(fromApple.view());
        text(String.format("%.1f GB free on this phone; iOS 12 needs about 5 GB, and 2 GB more for a save.",
                getFilesDir().getUsableSpace() / 1e9), 13, 0xff888888).setPadding(0, 28, 0, 28);
        bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(1000);
        bar.setVisibility(View.GONE);
        box.addView(bar);
        status = text("", 15, Color.WHITE);
        status.setGravity(Gravity.START);
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != PICK || res != RESULT_OK || data == null || data.getData() == null) {
            return;
        }
        Uri u = data.getData();
        long size = -1;
        try (Cursor c = getContentResolver().query(u, new String[] {OpenableColumns.SIZE}, null, null, null)) {
            if (c != null && c.moveToFirst() && !c.isNull(0)) {
                size = c.getLong(0);
            }
        }
        try {
            run(getContentResolver().openInputStream(u), size, null);
        } catch (IOException e) {
            status.setText(e.getMessage());
        }
    }

    /** Asks first when it replaces something, then downloads in the background. */
    private void run(InputStream in, long total, File done) {
        if (busy) {
            return;
        }
        if (Guest.running()) {
            status.setText("Close iOS first (side bar > Saves > Save and close).");
            return;
        }
        if (Installer.hasData(this)) {
            new android.app.AlertDialog.Builder(this)
                    .setTitle("Replace iOS 12 on this phone?")
                    .setMessage("What the file replaces goes first: iOS 12's disk with its settings, apps and saves. "
                            + "Then the new one is copied in.")
                    .setPositiveButton("Replace", (d, w) -> importNow(in, total, done))
                    .setNegativeButton("Cancel", (d, w) -> {
                        try {
                            in.close();
                        } catch (IOException ignored) {
                            // nothing read
                        }
                    })
                    .show();
            return;
        }
        importNow(in, total, done);
    }

    private void importNow(InputStream in, long total, File done) {
        busy = true;
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        for (int i = 0; i < box.getChildCount(); i++) {
            if (box.getChildAt(i) instanceof Button) {
                box.getChildAt(i).setEnabled(false);
            }
        }
        bar.setVisibility(View.VISIBLE);
        status.setText("Starting… keep this screen open.");
        importRecord = null;
        long t0 = System.currentTimeMillis();
        long logAt = new java.io.File(Guest.runDir(this), "app.txt").length();
        AppExit.begin(this, AppExit.IMPORT, "an import from the PC was running");
        new Thread(() -> {
            String result;
            try (InputStream s = in) {
                String os = Installer.installAny(this, new java.io.BufferedInputStream(s, 1 << 20), total, (what, at, all) -> runOnUiThread(() -> {
                    bar.setIndeterminate(all <= 0);
                    if (all > 0) {
                        bar.setProgress((int) (at * 1000 / all));
                    }
                    status.setText(all > 0 ? String.format("%s: %.1f of %.1f GB", what, at / 1e9, all / 1e9) : what + "…");
                }));
                if (done != null) {
                    done.delete();
                }
                String notes = "12".equals(os) ? Installer.kernelNotes(this) : "";
                result = String.format("%s is set up (%d s).%s", "12".equals(os) ? "iOS 12" : os,
                        (System.currentTimeMillis() - t0) / 1000, notes.isEmpty() ? "" : "\n" + notes);
            } catch (IOException | RuntimeException e) {
                result = "Not set up: " + e.getMessage();
                AppLog.note(this, "import stopped: " + e);
                importRecord = SetupRecord.writeImport(this, e.getMessage(), e, total, logAt, t0);
            } finally {
                AppExit.end(this, AppExit.IMPORT);
            }
            String r = result;
            runOnUiThread(() -> finishRun(r));
        }, "setup-import").start();
    }

    private void finishRun(String result) {
        busy = false;
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        show();
        status.setText(result);
        String id = importRecord;
        if (id != null) {
            // under the failed import's line: its log, as under a failed setup step
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            Button share = new Button(this), report = new Button(this);
            share.setText("Share log");
            report.setText("Report on GitHub");
            for (Button b : new Button[] {share, report}) {
                b.setAllCaps(false);
                row.addView(b, new LinearLayout.LayoutParams(0, -2, 1));
            }
            share.setOnClickListener(v -> {
                CrashReport.Record rec = CrashReport.find(this, id);
                if (rec != null) {
                    CrashReport.share(this, rec);
                }
            });
            report.setOnClickListener(v -> {
                CrashReport.Record rec = CrashReport.find(this, id);
                if (rec != null) {
                    CrashReport.openIssue(this, rec);
                }
            });
            box.addView(row);
        }
        if (Installer.installed(this) && result.startsWith("iOS 12 is set up")) {
            Guest.select(this, Guest.IOS12);
            button("Start iOS 12 (the first start takes a few minutes)", v -> {
                startActivity(new Intent(this, ScreenActivity.class));
                finish();
            });
        }
    }
}
