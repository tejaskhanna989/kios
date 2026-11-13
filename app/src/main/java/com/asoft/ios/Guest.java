package com.asoft.ios;

import android.content.Context;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * The iOS 16 machine, as qemu-sweet.py builds it, and its one QEMU process. The guest's files
 * (ram.bin and stub.bin from qemu-sweet.py, the root disk) are in a directory the app can read.
 */
final class Guest {
    static final long RAM_BASE = 0x40000000L;
    static final long FB_BASE = 0x9c000000L;        // qemu-sweet.py FB_BASE: the guest's ramfb framebuffer
    static final int FB_W = 1080, FB_H = 2400, FB_STRIDE = FB_W * 4;
    static final long STUB_PA = 0x40200000L;
    static final long KERNEL_PA = GuestImage.KERNEL_PA;     // ram.bin's load address for this guest

    static final long RAM_SIZE = 7L << 30;

    // -- which iOS: 16 (-M virt, ramfb, no GPU) or 12 (-M virt, ramfb, no GPU)

    static final int IOS16 = 16, IOS12 = 12;

    /** iOS 12 screen: 750x1334 (iPhone 6s/7/8 class). */
    static final int FB12_W = 750, FB12_H = 1334;
    /** iOS 12 RAM: 2 GiB. */
    static final long RAM_SIZE_12 = 2L << 30;
    /** iOS 12 kernel load address (XNU for arm64). */
    static final long KERNEL_PA_12 = 0x10000000L;
    static final long STUB_PA_12 = 0x10200000L;
    /** Above this Android has so little left that it may close the guest. */
    static final int RAM_TIGHT = 4096;

    /** What the screens call @os. */
    static String osName(int os) {
        return "iOS " + os;
    }
    /** The iOS of the QEMU that runs, or ran last. */
    private static volatile int runningOs = IOS12;

    /** The iOS the user chose last (the one Start, Restart and the notification start). */
    static int selected(Context c) {
        return c.getSharedPreferences("guest", Context.MODE_PRIVATE).getInt("os", IOS12);
    }

    static void select(Context c, int os) {
        c.getSharedPreferences("guest", Context.MODE_PRIVATE).edit().putInt("os", os).apply();
    }

    /** The iOS the screens are about: the running one, else the one chosen last. */
    static int os(Context c) {
        return running() ? runningOs : selected(c);
    }

    static int fbW() {
        return FB_W;
    }

    static int fbH() {
        return FB_H;
    }

    /** Maps the running guest's screen for Render.frame(); null when done, else why not. */
    static String openScreen(int forPid) {
        return Render.openFramebuffer(forPid, FB_BASE - RAM_BASE, FB_W, FB_H, FB_STRIDE);
    }

    /**
     * One of the iPhone's buttons (home, power, volup, voldown), @down or up: held until the up, so
     * iOS repeats a held volume button. iOS 16 has them as keys F1-F4 (bsd/dev/sweet_vinput.c).
     * An up comes at least MIN_HOLD_MS after its down: iOS reads a button only once it has been down.
     */
    static void button(String b, boolean down) {
        input();
        if (b.equals("power")) {
            lastPowerMs = lastInputMs;
        }
        Qmp q = qmp;
        if (q == null) {
            return;
        }
        long now = android.os.SystemClock.uptimeMillis();
        if (down) {
            held.put(b, now);
            buttonEdge(q, b, true);
            return;
        }
        Long since = held.remove(b);
        long wait = since == null ? 0 : MIN_HOLD_MS - (now - since);
        if (wait <= 0) {
            buttonEdge(q, b, false);
        } else {
            Thread t = new Thread(() -> {
                try {
                    Thread.sleep(wait);
                } catch (InterruptedException ignored) {
                    // up at once
                }
                buttonEdge(q, b, false);
            }, "button-up");
            t.setDaemon(true);
            t.start();
        }
    }

    private static final long MIN_HOLD_MS = 80;
    /** The buttons down now, with when (uptime ms). */
    private static final Map<String, Long> held = new java.util.concurrent.ConcurrentHashMap<>();

    private static void buttonEdge(Qmp q, String b, boolean down) {
        q.keyEvent(b.equals("home") ? "f1" : b.equals("power") ? "f2" : b.equals("voldown") ? "f3" : "f4", down);
    }

    /** Lets go of every button held (the screen lost the keys: their ups will not come). */
    static void releaseButtons() {
        for (String b : held.keySet()) {
            button(b, false);
        }
    }

    /** When the user last touched iOS or pressed one of its buttons (uptime ms): AutoSave waits for a quiet moment. */
    static volatile long lastInputMs = android.os.SystemClock.uptimeMillis();

    static void input() {
        lastInputMs = android.os.SystemClock.uptimeMillis();
    }

    /** When the app last pressed the side button (uptime ms): a display sleep right after it is not iOS's Auto-Lock. */
    static volatile long lastPowerMs;

    /** A press and release of @b. */
    static void button(String b) {
        input();
        if (b.equals("power")) {
            lastPowerMs = lastInputMs;
        }
        Qmp q = qmp;
        if (q == null) {
            return;
        }
        q.key(b.equals("home") ? "f1" : b.equals("power") ? "f2" : b.equals("voldown") ? "f3" : "f4");
    }

    /**
     * The quick-boot state's name inside the user disk (qcow2 internal snapshot). It lives in one of
     * two slots, QUICK and QUICK_B: a new quick save goes into the other slot and the old one is
     * deleted only once the new one is complete. QEMU's savevm deletes a snapshot of the same name
     * before it writes the new one, so a save that died half way (the app killed, the phone full) lost
     * the old state too and the next start booted (2026-11-06). With too little room for two, a save
     * still goes over the old slot.
     */
    static final String QUICK = "asoft-quick";
    static final String QUICK_B = "asoft-quick-b";

    static boolean isQuick(String tag) {
        return QUICK.equals(tag) || QUICK_B.equals(tag);
    }

    /** The newest quick slot in @saves (newest first, as snapshots() gives them), else null. */
    static Snap newestQuick(List<Snap> saves) {
        for (Snap s : saves) {
            if (isQuick(s.tag)) {
                return s;
            }
        }
        return null;
    }

    /** "3.21 GiB" (a VM SIZE of the snapshot list) in bytes, 0 when it cannot be read. */
    static long sizeBytes(String size) {
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("([\\d.]+)\\s*([KMGT]?)i?B?").matcher(size.trim());
        if (!m.find()) {
            return 0;
        }
        double v = Double.parseDouble(m.group(1));
        String u = m.group(2);
        int shift = u.equals("K") ? 10 : u.equals("M") ? 20 : u.equals("G") ? 30 : u.equals("T") ? 40 : 0;
        return (long) (v * (1L << shift));
    }

    /** Why the last start did not happen (no room, ...), for the screens; null once a start is under way. */
    static volatile String startError;
    private static int pid = -1;
    private static volatile Qmp qmp;
    static volatile String state = "stopped";
    /** What a start does before QEMU runs when it takes a while (state "preparing"), for the screen; else null. */
    static volatile String preparing;
    /** True when this QEMU was started from the saved state. */
    static volatile boolean resumed;
    static volatile String loadedTag;
    private static final java.util.concurrent.atomic.AtomicBoolean saving = new java.util.concurrent.atomic.AtomicBoolean();

    static File runDir(Context c) {
        File d = new File(c.getFilesDir(), "run");
        d.mkdirs();
        return d;
    }

    static String qmpPath(Context c) {
        return new File(runDir(c), "qmp.sock").getPath();
    }

    /** The adb test folder (debug builds): ram.bin, stub.bin and disk.qcow2 made on the PC. */
    static final File TEST_DIR = new File("/data/local/tmp/asoft/ios16-app");

    /** Where payload.bin (or ram.bin and stub.bin) and disk.qcow2 are: what Set up brought in, else the test folder. */
    static File guestDir(Context c) {
        if (Installer.installed(c)) {
            return Installer.dir(c);
        }
        return TEST_DIR;
    }

    /**
     * What iOS's apps may run that this phone's CPU cannot: the native EL0 engine runs them on
     * the CPU as they are, and the guest CPU (cortex-a76, ARMv8.2) tells iOS it has LSE atomics,
     * RDM, dot product, FP16, RCpc and DC CVAP, so its libraries use them. Without one of them a
     * process would die of an undefined instruction: such a phone (an ARMv8.0 Cortex-A53/A73, say)
     * runs iOS under TCG only. Empty when the CPU has them all.
     */
    static String nativeMissing() {
        String[] need = {"atomics", "asimdrdm", "asimddp", "fphp", "asimdhp", "lrcpc", "dcpop"};
        java.util.Set<String> have = new java.util.HashSet<>();
        try {
            for (String l : java.nio.file.Files.readAllLines(new File("/proc/cpuinfo").toPath())) {
                if (l.startsWith("Features")) {
                    have.addAll(java.util.Arrays.asList(l.substring(l.indexOf(':') + 1).trim().split("\\s+")));
                    break;     // every core of a phone has the same feature list
                }
            }
        } catch (IOException e) {
            return "a readable /proc/cpuinfo";
        }
        StringBuilder m = new StringBuilder();
        for (String f : need) {
            if (!have.contains(f)) {
                m.append(m.length() > 0 ? " " : "").append(f);
            }
        }
        return m.toString();
    }

    /** Something to start: iOS was set up, or a debug build has the test folder. */
    static boolean available(Context c) {
        return Installer.installed(c)
                || (c.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
                && new File(TEST_DIR, "ram.bin").canRead();
    }

    /**
     * What iOS writes (settings, apps, the quick-boot state) goes to this overlay of the
     * read-only root disk; deleting it erases the iPhone.
     */
    static File userDisk(Context c) {
        return new File(c.getFilesDir(), "ios12-user.qcow2");
    }

    /** "ios12-user": iOS keeps its screen's scale in its MobileGestalt cache from the first boot on. */
    private static String diskName(Context c, int forOs) {
        return "ios" + forOs + "-user";
    }

    /** Every file of @forOs's own among the app's files (its install folder is Installer's): what one of its disk names
     * starts (diskName: the user disk, one an install kept as .old, the home screen's picture, each save's notes,
     * which erase deletes for one disk). For Installer.remove.
     */
    static List<File> ownFiles(Context c, int forOs) {
        List<String> starts = new ArrayList<>();
        starts.add(diskName(c, forOs) + ".");
        List<File> out = new ArrayList<>();
        File[] f = c.getFilesDir().listFiles();
        for (File x : f == null ? new File[0] : f) {
            for (String s : starts) {
                if (x.getName().startsWith(s)) {
                    out.add(x);
                    break;
                }
            }
        }
        return out;
    }

    /**
     * After Installer.remove: what the "guest" preferences keep of @forOs goes, each of its disks' marks (a stale quick
     * save, dirty, checked) and its screen and memory choices, so that a new install starts from the defaults. When it
     * was the one chosen, the choice goes to a system still on the phone (iOS 16; with none, as on a fresh app), its
     * start error with it. "stale-from-log-done" stays: the app's log still holds the old iOS 16's lines, which must not
     * mark a new one's quick save stale.
     */
    static void forgetSystem(Context c, int forOs) {
        android.content.SharedPreferences.Editor e = c.getSharedPreferences("guest", Context.MODE_PRIVATE).edit();
        for (String d : new String[] {diskName(c, forOs)}) {
            e.remove(staleKey(d)).remove(dirtyKey(d)).remove(CHECKED + d);
        }
        if (selected(c) == forOs) {
            if (!available(c)) {
                e.remove("os");
            } else {
                e.putInt("os", IOS12);
            }
            startError = null;
        }
        e.commit();
    }

    /**
     * A small picture of @forOs's screen as it last looked (ScreenActivity.keepThumb writes it), for the home
     * screen's device (DeviceView): beside the user disk, one per disk.
     */
    static File thumbFile(Context c, int forOs) {
        return new File(c.getFilesDir(), diskName(c, forOs) + ".thumb.jpg");
    }

    /** What sits next to the user disk for one save: "ios16-user.<tag>.leds" and the like. */
    private static String userPrefix(Context c) {
        return diskName(c, os(c)) + ".";
    }

    /**
     * The guest's RAM (MiB): iOS 12 runs with 2 GiB of RAM; iOS 16 runs with 7 GiB.
     */
    static int ramMiB(Context c) {
        return runningOs == IOS12 ? 2048 : 7168;
    }

    /** The RAM (MiB) iOS booted with. */
    private static volatile int bootRamMiB;

    static int bootRamMiB() {
        return bootRamMiB;
    }

    private static File savedRamFile(Context c, String tag) {
        return new File(c.getFilesDir(), userPrefix(c) + tag + ".ram");
    }

    /** What save @tag opens with: vCPUs and RAM; iOS 16's RAM is fixed at 7 GiB, iOS 12's at 2 GiB. */
    static String hardware(Context c, String tag) {
        int cpus = savedCpus(c, tag);
        return cpus + " vCPU" + (runningOs == IOS12 ? ", 2 GiB RAM" : ", 7 GiB RAM");
    }

    private static void ensureUserDisk(Context c, File g) throws IOException {
        File u = userDisk(c);
        if (u.exists()) {
            return;
        }
        String[] r = Emu.qemuImg(c, "create", "-q", "-f", "qcow2", "-F", "qcow2",
                "-b", new File(g, "disk.qcow2").getPath(), u.getPath());
        if (!"0".equals(r[0])) {
            u.delete();
            throw new IOException("qemu-img create: " + r[1].trim());
        }
    }

    /** One saved state (qcow2 internal snapshot) in the user disk. */
    static final class Snap {
        final String tag, size, date;

        Snap(String tag, String size, String date) {
            this.tag = tag;
            this.size = size;
            this.date = date;
        }

        /** What the user calls it: the quick-boot state is "Last close", "_" is a space. */
        String label() {
            return isQuick(tag) ? "Last close" : tag.replace('_', ' ');
        }
    }

    /** A row of "info snapshots" or "qemu-img snapshot -l": ID, TAG, VM size (number and unit), date. */
    private static final java.util.regex.Pattern SNAP_ROW = java.util.regex.Pattern.compile(
            "^\\s*\\S+\\s+(\\S+)\\s+([\\d.]+\\s*\\S+)\\s+(\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d)");

    /** The saved states, newest first; through QMP while iOS runs (the disk is open then). Not on the UI thread. */
    static List<Snap> snapshots(Context c) {
        String text = "";
        Qmp q = qmp;
        if (running() && q != null) {
            String r = q.hmp("info snapshots", 15000);
            try {
                text = r == null ? "" : new org.json.JSONObject(r).optString("return", "");
            } catch (org.json.JSONException ignored) {
                // no list
            }
        } else if (userDisk(c).exists() && !running()) {
            try {
                text = Emu.qemuImg(c, "snapshot", "-l", userDisk(c).getPath())[1];
            } catch (IOException ignored) {
                // no list
            }
        }
        List<Snap> out = new ArrayList<>();
        for (String line : text.split("\\r?\\n")) {
            java.util.regex.Matcher m = SNAP_ROW.matcher(line);
            if (m.find()) {
                out.add(new Snap(m.group(1), m.group(2), m.group(3)));
            }
        }
        out.sort((a, b) -> b.date.compareTo(a.date));
        // both quick slots: a save's last second (the old one not deleted yet); only the newer counts
        boolean seen = false;
        for (java.util.Iterator<Snap> it = out.iterator(); it.hasNext(); ) {
            if (isQuick(it.next().tag)) {
                if (seen) {
                    it.remove();
                }
                seen = true;
            }
        }
        return out;
    }

    /** The quick slots in the user disk, newest first, both of them (QEMU not running on it). */
    private static List<Snap> quickSlots(Context c) {
        List<Snap> out = new ArrayList<>();
        try {
            String text = Emu.qemuImg(c, "snapshot", "-l", userDisk(c).getPath())[1];
            for (String line : text.split("\\r?\\n")) {
                java.util.regex.Matcher m = SNAP_ROW.matcher(line);
                if (m.find() && isQuick(m.group(1))) {
                    out.add(new Snap(m.group(1), m.group(2), m.group(3)));
                }
            }
        } catch (IOException ignored) {
            // no list
        }
        out.sort((a, b) -> b.date.compareTo(a.date));
        return out;
    }

    /** A save's vCPU count; 4 for the saves made before 0.1.2, which all had four. */
    static int savedCpus(Context c, String tag) {
        try {
            int n = Integer.parseInt(new String(java.nio.file.Files.readAllBytes(
                    new File(c.getFilesDir(), diskName(c, runningOs) + "." + tag + ".cpus").toPath())).trim());
            return n >= 1 && n <= 8 ? n : 4;
        } catch (IOException | NumberFormatException e) {
            return 4;
        }
    }

    /**
     * Before a start that wants the quick-boot state: the newest quick slot's tag (an older one, left by a
     * save whose last second did not come, goes now), or QUICK when there is none (then the start boots).
     */
    private static String resolveQuick(Context c, String loadTag) {        if (!QUICK.equals(loadTag) || !userDisk(c).exists()) {
            return loadTag;
        }
        List<Snap> q = quickSlots(c);
        for (int i = 1; i < q.size(); i++) {
            String why = deleteSnapshot(c, q.get(i).tag);
            AppLog.note(c, "an older quick save " + q.get(i).tag + " (" + q.get(i).date + ") beside "
                    + q.get(0).tag + ": " + (why == null ? "deleted" : "not deleted: " + why));
        }
        return q.isEmpty() ? QUICK : q.get(0).tag;
    }

    /**
     * A quick save of the running iOS through @q, QEMU paused or not: into the slot the newest quick save
     * is not in, then the old one goes; over the old slot when the phone has no room for both. Null when
     * saved, else why not.
     */
    private static String saveQuick(Context c, Qmp q) {
        List<Snap> now = new ArrayList<>();
        String r = q.hmp("info snapshots", 15000);
        try {
            String text = r == null ? "" : new org.json.JSONObject(r).optString("return", "");
            for (String line : text.split("\\r?\\n")) {
                java.util.regex.Matcher m = SNAP_ROW.matcher(line);
                if (m.find() && isQuick(m.group(1))) {
                    now.add(new Snap(m.group(1), m.group(2), m.group(3)));
                }
            }
        } catch (org.json.JSONException ignored) {
            // no list: a save over QUICK
        }
        now.sort((a, b) -> b.date.compareTo(a.date));
        Snap old = now.isEmpty() ? null : now.get(0);
        String target = old == null || QUICK_B.equals(old.tag) ? QUICK : QUICK_B;
        long free = c.getFilesDir().getUsableSpace();
        long room = (old == null ? 4L << 30 : sizeBytes(old.size)) + (1L << 30);
        if (old != null && free < room) {
            target = old.tag;           // no room for two: QEMU deletes the old one first, as before
            AppLog.note(c, String.format(java.util.Locale.ROOT, "quick save over %s: %.1f GB free, two saves need %.1f GB",
                    old.tag, free / 1e9, room / 1e9));
        }
        synchronized (KBD) {        // the save and its note of the machine it was made in: no unplug in between
            String s = q.hmp("savevm " + target, 600000);
            if (s == null || !s.replace(" ", "").equals("{\"return\":\"\"}")) {
                return "savevm " + target + ": " + s;
            }
            keepLeds(c, target);
        }
        for (Snap o : now) {
            if (!o.tag.equals(target)) {
                String d = q.hmp("delvm " + o.tag, 60000);
                savedLedsFile(c, o.tag).delete();
                savedCpusFile(c, o.tag).delete();
                savedRamFile(c, o.tag).delete();
                if (d == null || !d.replace(" ", "").equals("{\"return\":\"\"}")) {
                    AppLog.note(c, "the older quick save " + o.tag + " stays until the next start: delvm " + d);
                }
            }
        }
        return null;
    }

    static boolean hasSnapshot(Context c, String tag) {
        for (Snap s : snapshots(c)) {
            if (s.tag.equals(tag)) {
                return true;
            }
        }
        return false;
    }

    /** A user's name for a save as a snapshot tag: letters, digits, - and _ (a space becomes _). */
    static String tagFor(String name) {
        String t = name.trim().replace(' ', '_').replaceAll("[^A-Za-z0-9_-]", "");
        if (t.length() > 40) {
            t = t.substring(0, 40);
        }
        return t.isEmpty() || isQuick(t) ? null : t;
    }

    /** Drops a saved state; with iOS running through QMP, else with qemu-img. Not on the UI thread. */
    static String deleteSnapshot(Context c, String tag) {
        savedLedsFile(c, tag).delete();
        savedCpusFile(c, tag).delete();
        savedRamFile(c, tag).delete();
        Qmp q = qmp;
        if (running() && q != null) {
            String r = q.hmp("delvm " + tag, 60000);
            return r != null && r.replace(" ", "").equals("{\"return\":\"\"}") ? null : "delvm: " + r;
        }
        try {
            String[] r = Emu.qemuImg(c, "snapshot", "-d", tag, userDisk(c).getPath());
            // gone already counts as deleted
            return "0".equals(r[0]) || r[1].contains("not found") ? null : r[1].trim();
        } catch (IOException e) {
            return e.toString();
        }
    }

    /** Both quick slots (deleteSnapshot counts a missing one as deleted): null when both are gone, else why not. */
    private static String deleteQuick(Context c) {
        // delvm (QEMU running) skips a slot that is not there; qemu-img's "not found" counts as deleted
        String a = deleteSnapshot(c, QUICK);
        String b = deleteSnapshot(c, QUICK_B);
        return a != null ? a : b;
    }

    /**
     * Drops the quick-boot state (a load of it failed for good): the next start boots iOS. Null when it is
     * gone; else why not, and it stays marked stale: never loaded by itself (quickStale).
     */
    static String dropQuick(Context c) {
        setQuickStale(c, true);
        String why = deleteQuick(c);
        if (why == null) {
            setQuickStale(c, false);
        } else {
            AppLog.note(c, "the quick save stays until the next start (then deleted, never loaded): " + why);
        }
        return why;
    }

    /**
     * The quick save is not where iOS is any more: Turn off (iOS shut down after it; it stays as a way back
     * until the next quick save replaces it), or a load of it that failed and could not be deleted. It never
     * loads by itself, or the disk would go back to that save; only goBack loads it, when the user asks.
     */
    private static String staleKey(Context c) {
        return staleKey(diskName(c, IOS16));
    }

    private static String staleKey(String disk) {
        return "quick-stale-" + disk;
    }

    static boolean quickStale(Context c) {
        return c.getSharedPreferences("guest", Context.MODE_PRIVATE).getBoolean(staleKey(c), false);
    }

    private static void setQuickStale(Context c, boolean stale) {
        c.getSharedPreferences("guest", Context.MODE_PRIVATE).edit().putBoolean(staleKey(c), stale).commit();
    }

    /**
     * 0.1.1 left no mark when its Turn off could not delete the quick save: its own log shows it, a
     * "power off" after the last "save". Read once, for iOS 16 (0.1.1 had no other).
     */
    private static void staleFromOldLog(Context c) {
        android.content.SharedPreferences p = c.getSharedPreferences("guest", Context.MODE_PRIVATE);
        if (p.getBoolean("stale-from-log-done", false)) {
            return;
        }
        int lastSave = -1, lastOff = -1, lastFail = -1, i = 0;
        try {
            for (String l : java.nio.file.Files.readAllLines(new File(runDir(c), "app.txt").toPath())) {
                if (l.contains(" save: saved in ")) {
                    lastSave = i;
                } else if (l.contains(" power off: ")) {
                    lastOff = i;
                } else if (l.contains("snapshot -d " + QUICK) && l.contains("lock")) {
                    lastFail = i;
                }
                i++;
            }
        } catch (IOException ignored) {
            // no log: nothing to read
        }
        if (lastOff > lastSave && lastFail > lastSave && userDisk(c).exists()) {
            setQuickStale(c, true);
            AppLog.note(c, "the log shows a Turn off whose quick-save delete failed: the old quick save is not loaded");
        }
        p.edit().putBoolean("stale-from-log-done", true).apply();
    }

    /**
     * Before a start: a stale quick save (the way back after a Turn off) stays on the disk, but @loadTag never
     * names it: the start boots. The next quick save replaces it (saveQuick's rotation), or goBack loads it.
     */
    private static String dropStaleQuick(Context c, String loadTag) {
        staleFromOldLog(c);
        if (!quickStale(c)) {
            return resolveQuick(c, loadTag);
        }
        if (isQuick(loadTag)) {
            AppLog.note(c, "the quick save is a way back (after a Turn off), not loaded: booting");
        }
        return isQuick(loadTag) ? null : loadTag;
    }

    static boolean isWayBack(Context c, Snap quick) {
        return quick != null && isQuick(quick.tag) && quickStale(c);
    }

    static boolean otherHardware(Context c, String tag) {
        return false;   // iOS 16: RAM is fixed, so no hardware change
    }

    /**
     * The user chose to go back to @forOs's way back @tag: it is the normal quick save again and opens with its own
     * hardware; its memory size counts as accepted for this disk's quick saves until the setting changes (boots keep
     * the setting). The caller then starts iOS, or loads it into the running one.
     */
    static void goBack(Context c, String tag) {
        setQuickStale(c, false);
        AppLog.note(c, "going back to the quick save " + tag + " (" + hardware(c, tag) + ")");
    }

    private static String quickWithOtherHardware(Context c, String loadTag) {
        return loadTag;
    }

    // -- the user disk's health

    private static String dirtyKey(Context c) {
        return dirtyKey(diskName(c, IOS16));
    }

    private static String dirtyKey(String disk) {
        return "dirty-" + disk;
    }

    /** Set while QEMU runs on the disk; cleared when the run ends cleanly (save and quit, shutdown, stop + quit). */
    private static void setDirty(Context c, boolean dirty) {
        c.getSharedPreferences("guest", Context.MODE_PRIVATE).edit().putBoolean(dirtyKey(c), dirty).commit();
    }

    /** Checked once after this build is installed, and after every run that did not end cleanly. */
    private static final String CHECKED = "disk-checked-v2-";

    /**
     * qemu-img check of the user disk (read only, ~seconds). Leaks (clusters nothing uses: what a
     * killed QEMU leaves) are harmless and freed at once. Errors in the disk's tables stop the start
     * with the counts, the disk as it is: what to do with it is the user's call.
     */
    private static void checkDisk(Context c) throws IOException {
        File u = userDisk(c);
        android.content.SharedPreferences p = c.getSharedPreferences("guest", Context.MODE_PRIVATE);
        boolean dirty = p.getBoolean(dirtyKey(c), false);
        if (!u.exists() || !dirty && p.getBoolean(CHECKED + diskName(c, IOS16), false)) {
            return;
        }
        long t0 = System.currentTimeMillis();
        String[] r = Emu.qemuImg(c, "check", "--output=json", u.getPath());
        long corrupt = -1, leaks = -1, errors = -1;
        String out = r[1];
        int brace = out.indexOf('{');
        if (brace >= 0) {
            try {
                org.json.JSONObject j = new org.json.JSONObject(out.substring(brace));
                corrupt = j.optLong("corruptions", 0);
                leaks = j.optLong("leaks", 0);
                errors = j.optLong("check-errors", 0);
            } catch (org.json.JSONException ignored) {
                // counts unknown
            }
        }
        AppLog.note(c, "disk check " + u.getName() + (dirty ? " (the last run did not end cleanly)" : "") + ": exit "
                + r[0] + ", corruptions " + corrupt + ", leaks " + leaks + ", check errors " + errors + ", "
                + (System.currentTimeMillis() - t0) + " ms");
        if ("2".equals(r[0]) || corrupt > 0) {
            throw new IOException("iOS 16's disk has " + corrupt + " errors in its tables (qemu-img check);"
                    + " it was left as it is. The app's log has the details.");
        }
        if ("3".equals(r[0]) || leaks > 0) {
            String[] fix = Emu.qemuImg(c, "check", "-r", "leaks", u.getPath());
            AppLog.note(c, "disk check: freed the leaked clusters, exit " + fix[0]);
        }
        p.edit().putBoolean(CHECKED + diskName(c, IOS16), true).putBoolean(dirtyKey(c), false).commit();
    }

    /** iOS runs, writes and saves into the user disk: refuse to start below this much free room. */
    private static void checkRoom(Context c) throws IOException {
        long free = c.getFilesDir().getUsableSpace();
        List<Snap> q = userDisk(c).exists() ? quickSlots(c) : new ArrayList<>();
        long quick = q.isEmpty() ? 0 : sizeBytes(q.get(0).size);
        long need = Math.max(2L << 30, (4L << 30) - quick);
        AppLog.note(c, String.format(java.util.Locale.ROOT, "room: %.1f GB free, user disk %.1f GB, quick save %.1f GB,"
                + " needs %.1f GB", free / 1e9, userDisk(c).length() / 1e9, quick / 1e9, need / 1e9));
        if (free < need) {
            throw new IOException(String.format(java.util.Locale.ROOT, "Only %.1f GB free on this phone: iOS 16 needs"
                    + " %.1f GB to run and to save. Free space on the phone, or delete saves (side bar > Saves).",
                    free / 1e9, need / 1e9));
        }
    }

    /** The disk's request counts from QMP (query-blockstats), for the log: failed ones mean lost writes. */
    private static void logDiskStats(Context c, Qmp q) {
        if (q == null) {
            return;
        }
        String r = q.call("{\"execute\":\"query-blockstats\"}", 5000);
        if (r == null) {
            return;
        }
        try {
            org.json.JSONArray a = new org.json.JSONObject(r).getJSONArray("return");
            for (int i = 0; i < a.length(); i++) {
                org.json.JSONObject s = a.getJSONObject(i).optJSONObject("stats");
                if (s == null || s.optLong("rd_operations") + s.optLong("wr_operations") == 0) {
                    continue;
                }
                AppLog.note(c, "disk " + a.getJSONObject(i).optString("device", "?") + ": reads " + s.optLong("rd_operations")
                        + " (failed " + s.optLong("failed_rd_operations") + "), writes " + s.optLong("wr_operations")
                        + " (failed " + s.optLong("failed_wr_operations") + "), flushes " + s.optLong("flush_operations")
                        + " (failed " + s.optLong("failed_flush_operations") + ")");
            }
        } catch (org.json.JSONException ignored) {
            // no stats
        }
    }

    static File ledsFile(Context c) {
        return new File(runDir(c), "leds");
    }

    /**
     * Erase @forOs's iPhone: its user disk and what belongs to its saved states.
     */
    static void erase(Context c) {
        userDisk(c).delete();
        thumbFile(c, runningOs).delete();
        String prefix = diskName(c, runningOs) + ".";
        File[] f = c.getFilesDir().listFiles((d, n) -> n.startsWith(prefix)
                && (n.endsWith(".leds") || n.endsWith(".cpus") || n.endsWith(".ram")));
        if (f != null) {
            for (File x : f) {
                x.delete();
            }
        }
    }

    /** The LED byte when @tag was saved (the display's power then), next to the user disk. */
    private static File savedLedsFile(Context c, String tag) {
        return new File(c.getFilesDir(), userPrefix(c) + tag + ".leds");
    }

    private static int savedLeds(Context c, String tag) {
        try (java.io.FileInputStream in = new java.io.FileInputStream(savedLedsFile(c, tag))) {
            int b = in.read();
            return b < 0 ? 0 : b;
        } catch (IOException e) {
            return 0;
        }
    }

    private static void keepLeds(Context c, String tag) {
        try (java.io.FileOutputStream o = new java.io.FileOutputStream(savedLedsFile(c, tag))) {
            o.write(currentLeds(c));
        } catch (IOException ignored) {
            // the display then reads on after a load
        }
        keepCpus(c, tag);
    }

    private static File savedCpusFile(Context c, String tag) {
        return new File(c.getFilesDir(), userPrefix(c) + tag + ".cpus");
    }

    private static int currentLeds(Context c) {
        try (java.io.RandomAccessFile in = new java.io.RandomAccessFile(ledsFile(c), "r")) {
            int b = in.read();
            return b < 0 ? 0 : b;
        } catch (IOException e) {
            return 0;
        }
    }

    private static void keepCpus(Context c, String tag) {
        try (PrintWriter w = new PrintWriter(new FileWriter(savedCpusFile(c, tag)))) {
            w.println(bootCpus);
        } catch (IOException ignored) {
            // read as 4: a load then fails and the start falls back to a boot
        }
    }

    // -- QEMU's own ends, for the crash report (CrashReport)

    /** The QEMU the app asked to end (a stop, a save's quit, a turn off, the setup's end of a boot): its end is no crash. */
    private static volatile int endingByApp = -1;
    /** The QEMU whose end was looked at already. */
    private static int noticedPid = -1;
    /** What the crash report needs of the QEMU that runs (or ran last). */
    private static volatile CrashReport.Run run;

    /**
     * QEMU @p has ended (it was reaped): unless the app asked for that, its end is recorded (CrashReport). Once per
     * QEMU; with this class's lock held.
     */
    private static void noticeEnd(int p) {
        if (p <= 0 || p == noticedPid) {
            return;
        }
        noticedPid = p;
        // the app saw it end: a death of the app's process from now on is not "while iOS was running"
        AppExit.end(appContext, AppExit.GUEST);
        CrashReport.Run r = run;
        if (endingByApp == p || r == null || r.pid != p || appContext == null) {
            return;
        }
        CrashReport.captureAsync(appContext, r, Render.endStatus(p));
    }

    /**
     * The app is about to end QEMU @p. One that ended before it asked ended by itself (the service's stop after a
     * load that failed comes after QEMU died): that end is looked at first.
     */
    private static synchronized void appEnds(int p) {
        if (p > 0 && !Render.alive(p)) {
            noticeEnd(p);
        }
        endingByApp = p;
        AppExit.end(appContext, AppExit.GUEST);
    }

    /** The setup (PhoneSetup26.endBoot) quits its boot's QEMU itself: no crash. */
    static void willEnd() {
        int p;
        synchronized (Guest.class) {
            p = pid;
        }
        appEnds(p);
    }

    /**
     * Looks at QEMU @forPid twice a second until it ends, so an end nobody is waiting for (the screen closed, the
     * phone asleep) is recorded while its stderr is still there.
     */
    private static void watch(int forPid) {
        Thread t = new Thread(() -> {
            while (true) {
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    return;
                }
                synchronized (Guest.class) {
                    if (pid != forPid) {
                        return;
                    }
                    if (!Render.alive(forPid)) {
                        noticeEnd(forPid);
                        return;
                    }
                }
            }
        }, "qemu-watch");
        t.setDaemon(true);
        t.start();
    }

    /** The record of the QEMU just spawned (pid), and its watcher; with this class's lock held. */
    private static void track(int os, boolean setup, String start, long logAt, int cpus, int ramMiB, String screen, String engine) {
        CrashReport.Run r = new CrashReport.Run();
        r.pid = pid;
        r.os = os;
        r.setup = setup;
        r.start = start;
        r.startedMs = System.currentTimeMillis();
        r.appLogOffset = logAt;
        r.cpus = cpus;
        r.ramMiB = ramMiB;
        r.screen = screen;
        r.engine = engine;
        run = r;
        watch(pid);
        // a death of the app's process while it runs is noticed at the next start (a setup's boot is the setup's)
        if (!setup && appContext != null) {
            AppExit.begin(appContext, AppExit.GUEST, osName(os) + " was running");
        }
    }

    /** A stand-in QEMU for the crash test: reims' last words, as a real one says them, then SIGABRT. */
    private static final String CRASH_TEST = "cat >&2 <<'EOF'\n"
            + "reims[warn] create::function: Metal refused the function's IR: Error Domain=MTLLibraryErrorDomain Code=1\n"
            + "reims[warn] create::function: Metal refused the function's IR: Error Domain=MTLLibraryErrorDomain Code=1\n"
            + "reims-vgpu: fatal: platform call renderCommandEncoderWithDescriptor:: the Vulkan runtime refused it: unsupported:"
            + " Unsupported { feature: Format, needs: NotImplemented, location: None, symbol: None }; the pass's attachments:"
            + " colour 0 552 (BGR10_XR) Type2D usage 0x4 Private\n"
            + "EOF\n"
            // long enough to open the guest's screen over it (a screen opened on nothing running starts the guest)
            + "sleep 10\n"
            + "kill -ABRT $$\n";

    /**
     * Debug builds: the whole crash report path on the phone without a guest or a disk. A shell stands in for
     * QEMU, says what reims says when it gives up, and aborts; the record, the notification and the screens'
     * "Report this crash" follow as for a real one.
     */
    static synchronized void startCrashTest(Context c) throws IOException {
        if ((c.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            throw new IOException("the crash test is in debug builds only");
        }
        if (running()) {
            throw new IOException(osName(runningOs) + " is running: close it first");
        }
        if (qmp != null) {
            qmp.close();
            qmp = null;
        }
        appContext = c.getApplicationContext();
        int os = selected(c);
        runningOs = os;
        CrashReport.awaitCapture(15_000);
        long logAt = new File(runDir(c), "app.txt").length();
        CrashReport.startedAgain(c, os);
        AppLog.keepRunLogs(c);
        AppLog.note(c, "crash test: a stand-in QEMU that aborts");
        List<String> envp = new ArrayList<>();
        for (Map.Entry<String, String> e : System.getenv().entrySet()) {
            envp.add(e.getKey() + "=" + e.getValue());
        }
        endingByApp = -1;
        noticedPid = -1;
        resumed = false;
        loadedTag = null;
        // (the files dir as every QEMU's: Render.spawn)
        pid = Render.spawn(new String[] {"/system/bin/sh", "-c", CRASH_TEST}, envp.toArray(new String[0]),
                new File(runDir(c), "qemu-stderr.txt").getPath(), c.getFilesDir().getPath());
        if (pid < 0) {
            throw new IOException("cannot start the crash test");
        }
        state = "booting";
        // the engine the system runs on, so the record's engine line (and its SHA-1) is a real one
        track(runningOs, false, "a crash test", logAt, bootCpus, ramMiB(c), "", Emu.qemuPath(c));
    }

    static synchronized int pid(Context c) {
        return pid;
    }

    /** The guest's one QMP connection, or null while there is none (input is dropped then). */
    static Qmp qmp() {
        return qmp;
    }

    /** Connects QMP in the background once QEMU listens; QEMU takes one client, this is it. */
    private static void connectQmp(Context c, int forPid) {
        Thread t = new Thread(() -> {
            File sock = new File(qmpPath(c));
            // a saved state loads before QEMU answers: minutes, on a cold phone
            for (int i = 0; i < 3000 && Render.alive(forPid) && pid == forPid; i++) {
                if (sock.exists()) {
                    Qmp q = new Qmp();
                    try {
                        q.connect(sock.getPath(), 5000);
                        qmp = q;
                        return;
                    } catch (IOException e) {
                        q.close();
                    }
                }
                try {
                    Thread.sleep(200);
                } catch (InterruptedException e) {
                    return;
                }
            }
        }, "qmp-connect");
        t.setDaemon(true);
        t.start();
    }

    /**
     * The DNS servers of the active network, for slirp, which reads a relative resolv.conf from QEMU's
     * working directory, the files dir (patch-slirp.py, Render.spawn); public ones as a fallback.
     */
    private static void writeResolvConf(Context c) throws IOException {
        StringBuilder sb = new StringBuilder();
        android.net.ConnectivityManager cm = c.getSystemService(android.net.ConnectivityManager.class);
        android.net.LinkProperties lp = cm.getLinkProperties(cm.getActiveNetwork());
        if (lp != null) {
            for (java.net.InetAddress a : lp.getDnsServers()) {
                sb.append("nameserver ").append(a.getHostAddress()).append('\n');
            }
        }
        sb.append("nameserver 8.8.8.8\nnameserver 1.1.1.1\n");
        try (PrintWriter w = new PrintWriter(new FileWriter(new File(c.getFilesDir(), "resolv.conf")))) {
            w.print(sb);
        }
    }

    /** The end of QEMU's stderr: why it stopped, for the screen. */
    static String lastWords(Context c) {
        try {
            java.util.List<String> lines = java.nio.file.Files.readAllLines(new File(runDir(c), "qemu-stderr.txt").toPath());
            for (int i = lines.size() - 1; i >= 0 && i >= lines.size() - 40; i--) {
                String l = lines.get(i);
                if (l.contains("host signal") || l.contains("died") || l.contains("Error") || l.contains("error")) {
                    return l.length() > 200 ? l.substring(0, 200) : l;
                }
            }
        } catch (IOException ignored) {
            // no log yet
        }
        return "";
    }

    /**
     * Why the guest that ran last stopped, in the screen's words, from QEMU's stderr: the phone's storage, the
     * GPU layer, Android's mapping limit, else QEMU's own last error line; "" when it said nothing.
     */
    static String stopReason(Context c) {
        String err;
        try {
            err = new String(java.nio.file.Files.readAllBytes(new File(runDir(c), "qemu-stderr.txt").toPath()),
                    java.nio.charset.StandardCharsets.ISO_8859_1);
        } catch (IOException e) {
            err = "";
        }
        String tail = err.length() > 20_000 ? err.substring(err.length() - 20_000) : err;
        if (tail.contains("No space left on device") || tail.contains("ENOSPC")) {
            return String.format(java.util.Locale.ROOT, "the phone's storage is full (%.1f GB free). Free some space,"
                    + " then start it again: its disk and saves are kept.", c.getFilesDir().getUsableSpace() / 1e9);
        }
        if (tail.contains("reims-vgpu: fatal")) {
            // metal2vulkan met something it does not translate yet (2026-11-07: a compute kernel's texture
            // format on the watch) and reims ends QEMU rather than draw wrong
            return "its graphics asked the phone's GPU for something this version cannot do yet. Start it again:"
                    + " its disk and saves are kept.";
        }
        String why = lastWords(c);
        if (why.contains("max_map_count") || why.contains("kernel mappings")) {
            return "its graphics memory used up the memory mappings Android gives an app (a known limit"
                    + " of this version). Start it again; its disk and saves are kept.";
        }
        return why;
    }

    /** QEMU's Scroll Lock LED bit: ASoftware's XNU lights it while iOS has the display off (xnu 0102). */
    static final int SCROLL_LOCK_LED = 1;
    /** The keyboard/saves lock: keeps save+note atomic. */
    private static final Object KBD = new Object();

    static synchronized boolean running() {
        boolean a = Render.alive(pid);
        if (!a && pid > 0) {
            noticeEnd(pid);
        }
        return a;
    }

    /** The QEMU stop() let go of: it may still hold the user disk for a few seconds. */
    private static volatile int endingPid = -1;

    /**
     * Until the QEMU before is gone (at most @ms): the last second of a save and close (QEMU has
     * quit but is not reaped yet), a stop() whose QEMU still ends. A start then would find the disk
     * locked, or find iOS "running" and do nothing (2026-11-05: the service then took the saved state
     * for one that does not load, and dropped it). True when it is gone.
     */
    static boolean waitEnded(long ms) {
        long end = System.currentTimeMillis() + ms;
        while (true) {
            int e = endingPid;
            if (e > 0 && !Render.alive(e)) {
                endingPid = -1;     // reaped: never wait on a pid a later QEMU may get
                e = -1;
            }
            if (!saving() && e <= 0) {
                return true;
            }
            if (System.currentTimeMillis() > end) {
                return false;
            }
            try {
                Thread.sleep(100);
            } catch (InterruptedException ex) {
                return false;
            }
        }
    }

    /**
     * True when a start from @tag failed for the state itself (QEMU could not load it), false when
     * QEMU never got that far (the disk locked by the QEMU before, no memory): then the state stays.
     */
    static boolean loadFailedForGood(Context c) {
        try {
            String err = new String(java.nio.file.Files.readAllBytes(new File(runDir(c), "qemu-stderr.txt").toPath()),
                    java.nio.charset.StandardCharsets.ISO_8859_1);
            return !(err.contains("Failed to get") && err.contains("lock")) && !err.contains("Cannot allocate memory");
        } catch (IOException e) {
            return false;
        }
    }

    /** Starts iOS: from the saved state @loadTag when there is one (QUICK: quick boot), else a boot. */
    static synchronized void start(Context c, String loadTag) throws IOException {
        resumed = false;    // until this start says otherwise: the service reads it after
        if (running()) {
            throw new IOException("iOS is running already");
        }
        if (qmp != null) {
            qmp.close();                // of a QEMU that is gone
            qmp = null;
        }
        File links = Emu.linkLibraries(c);
        writeResolvConf(c);
        runningOs = selected(c);
        appContext = c.getApplicationContext();
        File g = guestDir(c);
        File run = runDir(c);
        ensureUserDisk(c, g);
        loadTag = dropStaleQuick(c, loadTag);
        checkRoom(c);
        checkDisk(c);
        List<Snap> saves = loadTag == null ? new ArrayList<>() : snapshots(c);
        resumed = false;
        StringBuilder tags = new StringBuilder();
        for (Snap s : saves) {
            resumed |= s.tag.equals(loadTag);
            tags.append(tags.length() > 0 ? ", " : "").append(s.tag);
        }
        loadedTag = resumed ? loadTag : null;
        // the record of the QEMU before reads its stderr, which this start truncates
        CrashReport.awaitCapture(15_000);
        long logAt = new File(runDir(c), "app.txt").length();
        CrashReport.startedAgain(c, runningOs);
        AppLog.keepRunLogs(c);
        AppLog.note(c, "start: wanted " + (loadTag == null ? "a boot" : loadTag) + ", saves [" + tags + "] -> "
                + (resumed ? "-loadvm " + loadTag : "boot"));
        CpuPlan plan = CpuPlan.forThisPhone(c);
        // a saved state needs the vCPU count it was saved with
        int smp = resumed ? savedCpus(c, loadTag) : plan.smp;
        AppLog.note(c, "cpus: " + smp + " vCPUs" + (resumed && smp != plan.smp ? " (the save's)" : "")
                + ", pin " + (plan.pin.isEmpty() ? "none" : plan.pin) + "; " + plan.why);
        if (!resumed) {
            Installer.prepareBoot(c, g, smp);   // this phone's time zone, region, clock and cpus= in the boot-args
        }
        bootCpus = smp;
        new File(run, "qmp.sock").delete();
        // the guest keyboard's LEDs, one byte QEMU keeps current (ASOFT_LEDS_FILE): zero until iOS says
        // (written in place, never truncated: the screen reads it while this runs). QEMU's LED state
        // is not in a saved state and XNU only reports changes: a resumed guest starts from the LEDs
        // it had when it was saved, so a display saved off still reads off.
        try (java.io.RandomAccessFile o = new java.io.RandomAccessFile(ledsFile(c), "rw")) {
            o.write(resumed ? savedLeds(c, loadTag) : 0);
        }
        if (runningOs == IOS12) {
            start12(c, g, run, loadTag, resumed, smp, links, new ArrayList<>());
            return;
        }
        int ramFd = Render.createGuestRam(RAM_SIZE);
        if (ramFd < 0) {
            throw new IOException("no memfd for the guest's RAM");
        }
        List<String> cmd = new ArrayList<>(List.of(Emu.qemuPath(c),
                // no loadvm-catch-up: moving the clock under a loaded state trips XNU's spinlock timeouts
                // (a lock held at the save looks held for minutes); the kernel (xnu 0103) sets its
                // calendar from the PL031 within 5 s instead
                "-M", "virt,gic-version=3,memory-backend=m0",
                "-object", "memory-backend-memfd,id=m0,size=7G,share=on",
                "-cpu", "cortex-a76", "-smp", String.valueOf(smp), "-m", "7G",
                "-display", "none", "-monitor", "none", "-parallel", "none",
                "-device", "ramfb", "-device", "virtio-keyboard-device", "-device", "virtio-tablet-device",
                "-qmp", "unix:" + qmpPath(c) + ",server,nowait",
                "-serial", "file:" + new File(run, "serial.txt").getPath(),
                "-d", "guest_errors,unimp", "-D", new File(run, "qemu.log").getPath(),
                "-no-reboot", "-nic", "none",
                "-device", "loader,file=" + new File(g, "ram.bin").getPath() + ",addr=0x" + Long.toHexString(KERNEL_PA) + ",force-raw=on",
                "-device", "loader,file=" + new File(g, "stub.bin").getPath() + ",addr=0x" + Long.toHexString(STUB_PA) + ",force-raw=on",
                "-device", "loader,addr=0x" + Long.toHexString(STUB_PA) + ",cpu-num=0",
                "-global", "virtio-mmio.force-legacy=false",
                "-name", "ASoftware iOS",
                "-netdev", "user,id=net0", "-device", "virtio-net-device,netdev=net0",
                // cache=none (O_DIRECT): a save writes ~3 GB of RAM into the disk; through the page
                // cache that filled the phone's memory and lmkd killed the app (QEMU with it) mid-save
                "-drive", "file=" + userDisk(c).getPath() + ",if=none,id=root,cache=none,format=qcow2",
                "-device", "virtio-blk-device,drive=root"));
        if (resumed) {
            cmd.add("-loadvm");
            cmd.add(loadTag);
        }
        Map<String, String> env = new java.util.HashMap<>(System.getenv());
        Emu.baseEnv(c, links, env);
        env.put("ASOFT_GUEST_RAM_FD", String.valueOf(ramFd));    // our memfd, inherited: see render.c
        String missing = nativeMissing();
        if (missing.isEmpty()) {
            env.put("ASOFT_NATIVE_EL0", "1");
            env.put("ASOFT_NATIVE_EL0_TPIDRRO", "1");
            env.put("ASOFT_NATIVE_EL0_STUBS", "8");
            env.put("ASOFT_NATIVE_EL0_DELAY_MS", "20000");
            env.put("ASOFT_NATIVE_EL0_STATS", "1");
            // while this file exists EL0 stays under TCG: for comparing the two without a reboot
            env.put("ASOFT_NATIVE_EL0_OFF_FILE", new File(run, "native-off").getPath());
            CpuPlan cp16 = CpuPlan.forThisPhone(c);
            if (!cp16.pin.isEmpty()) {
                env.put("ASOFT_NATIVE_EL0_STUB_CPUS", cp16.pin);
            }
        } else {
            AppLog.note(c, "native EL0 off: this CPU lacks " + missing + "; iOS runs under TCG only");
        }
        CpuPlan cp16 = CpuPlan.forThisPhone(c);
        if (!cp16.pin.isEmpty()) {
            env.put("ASOFT_VCPU_CPUS", cp16.pin);   // QEMU pins each vCPU thread (tcg-accel-ops-mttcg.c)
        }
        env.put("ASOFT_EL_SAMPLER", "30");
        env.put("ASOFT_LEDS_FILE", ledsFile(c).getPath());
        try (PrintWriter w = new PrintWriter(new FileWriter(new File(run, "cmdline.txt")))) {
            w.println(String.join(" ", cmd));
        }
        List<String> envp = new ArrayList<>();
        for (Map.Entry<String, String> e : env.entrySet()) {
            envp.add(e.getKey() + "=" + e.getValue());
        }
        setDirty(c, true);
        endingByApp = -1;
        noticedPid = -1;
        pid = Render.spawn(cmd.toArray(new String[0]), envp.toArray(new String[0]),
                new File(run, "qemu-stderr.txt").getPath(), c.getFilesDir().getPath());
        if (pid < 0) {
            throw new IOException("cannot start QEMU");
        }
        state = resumed ? "resuming" : "booting";
        track(runningOs, false, resumed ? "the save " + loadTag : "a boot", logAt, smp, runningOs == IOS12 ? 2048 : 7168, "", Emu.qemuPath(c));
        connectQmp(c, pid);
    }

    /** For the ends that come without one (stop() on the UI thread). */
    private static volatile Context appContext;
    /** An automatic save may be running (AutoSave): a close or a turn off waits for it, at most 2 minutes. */
    private static void waitForSave() {
        for (int i = 0; i < 1200 && saving.get(); i++) {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                return;
            }
        }
    }

    /**
     * Save and close only (never saveNamed or the automatic save, after which iOS goes on): QEMU paused, the
     * release-ram capability makes the save free each page of iOS's RAM once it is written, so Android's
     * memory falls during the save instead of every page it had swapped out coming back at once (lmkd ended
     * the app, and the save, that way). QEMU then refuses to run that machine again; it only quits or loads.
     * An engine that refuses the capability saves as before, and so does one that accepts it without the
     * release (iOS 16's libqemu.so, iOS 26 engines from before 2026-11-10).
     */
    private static void releaseRamWhileSaving(Context c, Qmp q) {
        String r = q.call("{\"execute\":\"migrate-set-capabilities\",\"arguments\":{\"capabilities\":"
                + "[{\"capability\":\"release-ram\",\"state\":true}]}}", 10000);
        AppLog.note(c, "save and close: release-ram " + (r == null ? "got no answer"
                : r.contains("\"error\"") ? "refused: " + r : "set"));
    }

    static String saveAndQuit(Context c) {
        waitForSave();
        if (!saving.compareAndSet(false, true)) {
            return "already saving";
        }
        try {
            Qmp q = qmp;
            int p = pid;
            if (q == null || !Render.alive(p)) {
                return "iOS is not running";
            }
            state = "saving";
            long t0 = System.currentTimeMillis();
            String why = null;
            if (q.call("{\"execute\":\"stop\"}", 30000) == null) {
                why = "stop: no answer";
            } else {
                logDiskStats(c, q);
                releaseRamWhileSaving(c, q);
                MemoryCleaner.beforeSave(c);
                why = saveQuick(c, q);
            }
            long saved = System.currentTimeMillis() - t0;
            if (why == null) {
                setQuickStale(c, false);     // a new quick save replaced the stale one
            }
            appEnds(p);     // (not before the save: QEMU ending in savevm is a crash)
            q.call("{\"execute\":\"quit\"}", 10000);
            for (int i = 0; i < 100 && Render.alive(p); i++) {
                try {
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    break;
                }
            }
            if (Render.alive(p)) {
                stop();
            } else {
                forget();
                setDirty(c, false);     // QEMU flushed the disk and ended by itself
            }
            return why != null ? why : "saved in " + saved + " ms";
        } finally {
            saving.set(false);
        }
    }

    /**
     * A named save while iOS goes on: iOS pauses for it (~25 s) and continues. Null when saved,
     * else why not. Not on the UI thread.
     */
    static String saveNamed(Context c, String tag) {
        if (!saving.compareAndSet(false, true)) {
            return "already saving";
        }
        try {
            Qmp q = qmp;
            if (q == null || !running()) {
                return "iOS is not running";
            }
            if (isQuick(tag)) {
                String why = saveQuick(c, q);
                if (why == null) {
                    setQuickStale(c, false);     // AutoSave's: it replaced a stale one
                }
                return why;
            }
            synchronized (KBD) {
                String r = q.hmp("savevm " + tag, 600000);
                if (r == null || !r.replace(" ", "").equals("{\"return\":\"\"}")) {
                    return "savevm: " + r;
                }
                keepLeds(c, tag);
            }
            return null;
        } finally {
            saving.set(false);
        }
    }

    static String powerOff(Context c) {
        waitForSave();
        if (!saving.compareAndSet(false, true)) {
            return "busy saving";
        }
        try {
            Qmp q = qmp;
            int p = pid;
            if (!Render.alive(p)) {
                return "iOS is not running";
            }
            appEnds(p);
            state = "turning off";
            // from here on the quick save is not where iOS is: never loaded again, even if its delete fails
            setQuickStale(c, true);
            logDiskStats(c, q);
            long t0 = System.currentTimeMillis();
            boolean clean = false;
            if (q != null && q.call("{\"execute\":\"system_powerdown\"}", 10000) != null) {
                for (int i = 0; i < 600 && Render.alive(p); i++) {
                    try {
                        Thread.sleep(100);
                    } catch (InterruptedException e) {
                        break;
                    }
                }
                clean = !Render.alive(p);
            }
            if (clean) {
                forget();
                setDirty(c, false);     // QEMU flushed the disk, ended by itself
            } else {
                stopAndWait();
            }
            long ms = System.currentTimeMillis() - t0;
            return (clean ? "turned off in " + ms + " ms" : "iOS did not turn off; QEMU stopped after " + ms + " ms")
                    + "; the quick save stays as a way back";
        } finally {
            saving.set(false);
        }
    }

    static boolean turningOff() {
        return "turning off".equals(state);
    }

    /** QEMU has ended by itself (and was reaped): let go of it without signalling a pid that may be reused. */
    private static synchronized void forget() {
        if (qmp != null) {
            qmp.close();
            qmp = null;
        }
        pid = -1;
        state = "stopped";
        // iOS 16's RAM is this app's memfd: its pages go back to the phone now (Render.releaseGuestRam)
        Render.releaseGuestRam();
    }

    static boolean saving() {
        return saving.get();
    }

    /** stop(), and wait (at most 30 s) until QEMU has gone and let go of the user disk. */
    static void stopAndWait() {
        int p = pid;
        appEnds(p);
        Render.terminate(p);
        for (int i = 0; i < 300 && Render.alive(p); i++) {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                break;
            }
        }
        boolean ended = !Render.alive(p);
        stop();
        if (ended) {
            Render.releaseGuestRam();       // as forget(): QEMU is gone, its RAM's pages need not stay
        }
    }

    /**
     * Ends iOS 26's QEMU, which does not end on SIGTERM (reims' teardown waits for GPU work that
     * never finishes once the vCPUs stop). A bare SIGKILL loses what qcow2 keeps in QEMU's memory
     * (the user disk's L2 and refcount tables): the next boot found iOS's Data volume corrupted
     * (2026-11-05). So QMP stop first, which pauses the vCPUs and flushes every disk, then quit,
     * SIGKILL last. Up to ~20 s: not on the UI thread.
     */
    /** iOS 26's ends in progress (end26 on its thread): a start waits for them. */
    private static final java.util.concurrent.atomic.AtomicInteger ending26 = new java.util.concurrent.atomic.AtomicInteger();

    private static void end26(Qmp q, int p) {
        ending26.incrementAndGet();
        try {
            end26Now(q, p);
        } finally {
            ending26.decrementAndGet();
        }
    }

    private static void end26Now(Qmp q, int p) {
        boolean asked = false;
        if (q != null && Render.alive(p)) {
            Context c = appContext;
            if (c != null) {
                logDiskStats(c, q);
            }
            asked = q.call("{\"execute\":\"stop\"}", 15000) != null;
            q.call("{\"execute\":\"quit\"}", 3000);
        }
        for (int i = 0; i < 50 && Render.alive(p); i++) {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                break;
            }
        }
        if (Render.alive(p)) {
            Render.forceKill(p);
        } else if (asked && appContext != null) {
            setDirty(appContext, runningOs, false);     // stop flushed the disk, quit ended QEMU
        }
        if (q != null) {
            q.close();
        }
    }

    static synchronized void stop() {
        if (pid > 0) {
            appEnds(pid);
        }
        endingPid = pid;
        Render.terminate(pid);
        if (qmp != null) {
            qmp.close();
            qmp = null;
        }
        pid = -1;
        state = "stopped";
    }

    /** Starts iOS 12: QEMU command line for the 64-bit virt machine. */
    private static void start12(Context c, File g, File run, String loadTag, boolean resumed, int smp,
            File links, List<String> envpBase) throws IOException {
        int ramFd = Render.createGuestRam(RAM_SIZE_12);
        if (ramFd < 0) {
            throw new IOException("no memfd for the guest's RAM");
        }
        List<String> cmd = new ArrayList<>(List.of(Emu.qemuPath(c),
                "-M", "virt,gic-version=3,memory-backend=m0",
                "-object", "memory-backend-memfd,id=m0,size=2G,share=on",
                "-cpu", "cortex-a76", "-smp", String.valueOf(smp), "-m", "2G",
                "-display", "none", "-monitor", "none", "-parallel", "none",
                "-device", "ramfb", "-device", "virtio-keyboard-device", "-device", "virtio-tablet-device",
                "-qmp", "unix:" + qmpPath(c) + ",server,nowait",
                "-serial", "file:" + new File(run, "serial.txt").getPath(),
                "-d", "guest_errors,unimp", "-D", new File(run, "qemu.log").getPath(),
                "-no-reboot", "-nic", "none",
                "-device", "loader,file=" + new File(g, "ram.bin").getPath() + ",addr=0x" + Long.toHexString(KERNEL_PA_12) + ",force-raw=on",
                "-device", "loader,file=" + new File(g, "stub.bin").getPath() + ",addr=0x" + Long.toHexString(STUB_PA_12) + ",force-raw=on",
                "-device", "loader,addr=" + Long.toHexString(STUB_PA_12) + ",cpu-num=0",
                "-global", "virtio-mmio.force-legacy=false",
                "-name", "ASoftware iOS 12",
                "-netdev", "user,id=net0", "-device", "virtio-net-device,netdev=net0",
                "-drive", "file=" + userDisk(c).getPath() + ",if=none,id=root,cache=none,format=qcow2",
                "-device", "virtio-blk-device,drive=root"));
        if (resumed) {
            cmd.add("-loadvm");
            cmd.add(loadTag);
        }
        Map<String, String> env = new java.util.HashMap<>(System.getenv());
        env.putAll(envMap(envpBase));
        Emu.baseEnv(c, links, env);
        env.put("ASOFT_GUEST_RAM_FD", String.valueOf(ramFd));
        String missing = nativeMissing();
        if (missing.isEmpty()) {
            env.put("ASOFT_NATIVE_EL0", "1");
            env.put("ASOFT_NATIVE_EL0_TPIDRRO", "1");
            env.put("ASOFT_NATIVE_EL0_STUBS", "8");
            env.put("ASOFT_NATIVE_EL0_DELAY_MS", "20000");
            env.put("ASOFT_NATIVE_EL0_STATS", "1");
            env.put("ASOFT_NATIVE_EL0_OFF_FILE", new File(run, "native-off").getPath());
            CpuPlan cp12 = CpuPlan.forThisPhone(c);
            if (!cp12.pin.isEmpty()) {
                env.put("ASOFT_NATIVE_EL0_STUB_CPUS", cp12.pin);
            }
        } else {
            AppLog.note(c, "native EL0 off: this CPU lacks " + missing + "; iOS runs under TCG only");
        }
        CpuPlan cp12 = CpuPlan.forThisPhone(c);
        if (!cp12.pin.isEmpty()) {
            env.put("ASOFT_VCPU_CPUS", cp12.pin);
        }
        env.put("ASOFT_EL_SAMPLER", "30");
        env.put("ASOFT_LEDS_FILE", ledsFile(c).getPath());
        try (PrintWriter w = new PrintWriter(new FileWriter(new File(run, "cmdline.txt")))) {
            w.println(String.join(" ", cmd));
        }
        List<String> envp = new ArrayList<>();
        for (Map.Entry<String, String> e : env.entrySet()) {
            envp.add(e.getKey() + "=" + e.getValue());
        }
        setDirty(c, true);
        endingByApp = -1;
        noticedPid = -1;
        pid = Render.spawn(cmd.toArray(new String[0]), envp.toArray(new String[0]),
                new File(run, "qemu-stderr.txt").getPath(), c.getFilesDir().getPath());
        if (pid < 0) {
            throw new IOException("cannot start QEMU");
        }
        state = resumed ? "resuming" : "booting";
        track(IOS12, false, resumed ? "the save " + loadTag : "a boot", logAt, smp, 2048, "", Emu.qemuPath(c));
        connectQmp(c, pid);
    }

    private static Map<String, String> envMap(List<String> envp) {
        Map<String, String> m = new java.util.HashMap<>();
        for (String e : envp) {
            int eq = e.indexOf('=');
            if (eq > 0) {
                m.put(e.substring(0, eq), e.substring(eq + 1));
            }
        }
        return m;
    }
}
