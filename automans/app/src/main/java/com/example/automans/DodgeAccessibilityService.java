package com.example.automans;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.SharedPreferences;
import android.graphics.Path;
import android.util.DisplayMetrics;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;

public class DodgeAccessibilityService extends AccessibilityService {
    private static volatile DodgeAccessibilityService instance;

    @Override
    protected void onServiceConnected() {
        instance = this;
        DodgeBus.STATUS.set("Accessibility подключён");
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {}

    @Override
    public void onInterrupt() {}

    @Override
    public void onDestroy() {
        if (instance == this) instance = null;
        super.onDestroy();
    }

    public static void performDodge(DodgeBus.Direction direction) {
        DodgeAccessibilityService s = instance;
        if (s == null) {
            DodgeBus.STATUS.set("Нужно включить Accessibility");
            return;
        }
        s.doDodge(direction);
    }

    @SuppressWarnings("deprecation")
    private void doDodge(DodgeBus.Direction direction) {
        SharedPreferences p = getSharedPreferences("cfg", MODE_PRIVATE);
        float joyXPercent = p.getFloat("joyX", 18f);
        float joyYPercent = p.getFloat("joyY", 78f);
        float distPercent = p.getFloat("dist", 11f);
        int duration = p.getInt("duration", 170);

        WindowManager wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        DisplayMetrics dm = new DisplayMetrics();
        wm.getDefaultDisplay().getRealMetrics(dm);

        float w = dm.widthPixels;
        float h = dm.heightPixels;
        float x0 = w * joyXPercent / 100f;
        float y0 = h * joyYPercent / 100f;
        float d = Math.min(w, h) * distPercent / 100f;

        float x1 = x0, y1 = y0;
        switch (direction) {
            case LEFT:  x1 -= d; break;
            case RIGHT: x1 += d; break;
            case UP:    y1 -= d; break;
            case DOWN:  y1 += d; break;
            default: return;
        }

        Path path = new Path();
        path.moveTo(x0, y0);
        path.lineTo(x1, y1);

        GestureDescription.StrokeDescription stroke =
                new GestureDescription.StrokeDescription(path, 0, duration);

        GestureDescription gesture = new GestureDescription.Builder()
                .addStroke(stroke)
                .build();

        dispatchGesture(gesture, null, null);
    }
}
