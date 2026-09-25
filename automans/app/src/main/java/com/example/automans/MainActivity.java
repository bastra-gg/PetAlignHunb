package com.example.automans;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.media.projection.MediaProjectionManager;
import android.os.*;
import android.provider.Settings;
import android.text.InputType;
import android.widget.*;

public class MainActivity extends Activity {
    private static final int REQ_CAPTURE = 1001;
    private TextView status;
    private EditText joyX, joyY, dist, duration;
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    public void onCreate(Bundle b) {
        super.onCreate(b);

        if (Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 9);
        }

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(36, 36, 36, 36);

        TextView title = new TextView(this);
        title.setText("Auto Mans — screen prototype");
        title.setTextSize(22);
        root.addView(title);

        TextView info = new TextView(this);
        info.setText("\n1) Включи Accessibility.\n2) Разреши захват экрана.\n3) Сначала смотри danger с AUTO OFF.\n");
        root.addView(info);

        Button access = new Button(this);
        access.setText("1. Открыть Accessibility");
        access.setOnClickListener(v ->
                startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        root.addView(access);

        Button capture = new Button(this);
        capture.setText("2. Запустить захват экрана");
        capture.setOnClickListener(v -> {
            MediaProjectionManager mpm =
                    (MediaProjectionManager)getSystemService(MEDIA_PROJECTION_SERVICE);
            startActivityForResult(mpm.createScreenCaptureIntent(), REQ_CAPTURE);
        });
        root.addView(capture);

        Switch autoSwitch = new Switch(this);
        autoSwitch.setText("AUTO: отправлять жест уклонения");
        autoSwitch.setChecked(DodgeBus.AUTO_ENABLED.get());
        autoSwitch.setOnCheckedChangeListener((buttonView, isChecked) ->
                DodgeBus.AUTO_ENABLED.set(isChecked));
        root.addView(autoSwitch);

        joyX = addField(root, "Joystick X, % ширины", "18");
        joyY = addField(root, "Joystick Y, % высоты", "78");
        dist = addField(root, "Длина уклонения, %", "11");
        duration = addField(root, "Длительность жеста, мс", "170");

        Button save = new Button(this);
        save.setText("Сохранить калибровку");
        save.setOnClickListener(v -> saveConfig());
        root.addView(save);

        status = new TextView(this);
        status.setTextSize(16);
        status.setPadding(0, 28, 0, 0);
        root.addView(status);

        ScrollView sc = new ScrollView(this);
        sc.addView(root);
        setContentView(sc);

        loadConfig();
        handler.post(statusLoop);
    }

    private EditText addField(LinearLayout root, String hint, String def) {
        TextView label = new TextView(this);
        label.setText(hint);
        root.addView(label);

        EditText e = new EditText(this);
        e.setText(def);
        e.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL);
        root.addView(e);
        return e;
    }

    private void saveConfig() {
        try {
            float x = Float.parseFloat(joyX.getText().toString());
            float y = Float.parseFloat(joyY.getText().toString());
            float d = Float.parseFloat(dist.getText().toString());
            int ms = Integer.parseInt(duration.getText().toString());

            getSharedPreferences("cfg", MODE_PRIVATE).edit()
                    .putFloat("joyX", x)
                    .putFloat("joyY", y)
                    .putFloat("dist", d)
                    .putInt("duration", ms)
                    .apply();

            Toast.makeText(this, "Сохранено", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Проверь числа", Toast.LENGTH_SHORT).show();
        }
    }

    private void loadConfig() {
        android.content.SharedPreferences p = getSharedPreferences("cfg", MODE_PRIVATE);
        joyX.setText(String.valueOf(p.getFloat("joyX", 18f)));
        joyY.setText(String.valueOf(p.getFloat("joyY", 78f)));
        dist.setText(String.valueOf(p.getFloat("dist", 11f)));
        duration.setText(String.valueOf(p.getInt("duration", 170)));
    }

    private final Runnable statusLoop = new Runnable() {
        @Override public void run() {
            status.setText(
                    "\nСтатус: " + DodgeBus.STATUS.get() +
                    "\nНаправление: " + DodgeBus.lastDirection +
                    "\nDanger: " + String.format("%.2f", DodgeBus.lastDanger) +
                    "\nAUTO: " + DodgeBus.AUTO_ENABLED.get()
            );
            handler.postDelayed(this, 300);
        }
    };

    @Override
    @SuppressWarnings("deprecation")
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_CAPTURE && resultCode == RESULT_OK && data != null) {
            Intent s = new Intent(this, CaptureService.class);
            s.putExtra("resultCode", resultCode);
            s.putExtra("data", data);
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(s);
            else startService(s);
        }
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacks(statusLoop);
        super.onDestroy();
    }
}
