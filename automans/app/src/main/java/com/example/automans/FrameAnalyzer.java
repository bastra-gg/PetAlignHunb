package com.example.automans;

import android.media.Image;
import java.nio.ByteBuffer;

public final class FrameAnalyzer {
    private static final int GW = 160;
    private static final int GH = 90;
    private static final int DIFF_THRESHOLD = 34;
    private static final long COOLDOWN_MS = 260;

    private byte[] prev = null;
    private final byte[] curr = new byte[GW * GH];

    public void analyze(Image image) {
        if (image == null) return;
        Image.Plane[] planes = image.getPlanes();
        if (planes.length == 0) return;

        Image.Plane plane = planes[0];
        ByteBuffer buf = plane.getBuffer();
        int pixelStride = plane.getPixelStride();
        int rowStride = plane.getRowStride();
        int width = image.getWidth();
        int height = image.getHeight();

        for (int gy = 0; gy < GH; gy++) {
            int sy = Math.min(height - 1, gy * height / GH);
            int row = sy * rowStride;
            for (int gx = 0; gx < GW; gx++) {
                int sx = Math.min(width - 1, gx * width / GW);
                int p = row + sx * pixelStride;
                if (p + 2 >= buf.limit()) continue;
                int r = buf.get(p) & 0xff;
                int g = buf.get(p + 1) & 0xff;
                int b = buf.get(p + 2) & 0xff;
                int y = (r * 77 + g * 150 + b * 29) >> 8;
                curr[gy * GW + gx] = (byte) y;
            }
        }

        if (prev == null) {
            prev = curr.clone();
            return;
        }

        final float cx = GW * 0.50f;
        final float cy = GH * 0.50f;
        final float maxR = Math.min(GW, GH) * 0.42f;
        final float minR = Math.min(GW, GH) * 0.06f;

        float riskL = 0f, riskR = 0f, riskU = 0f, riskD = 0f;
        float centerDanger = 0f;
        int changed = 0;
        int considered = 0;

        int x0 = (int)(GW * 0.08f), x1 = (int)(GW * 0.92f);
        int y0 = (int)(GH * 0.08f), y1 = (int)(GH * 0.88f);

        for (int gy = y0; gy < y1; gy += 2) {
            for (int gx = x0; gx < x1; gx += 2) {
                int i = gy * GW + gx;
                int a = curr[i] & 0xff;
                int b = prev[i] & 0xff;
                int d = Math.abs(a - b);
                considered++;
                if (d < DIFF_THRESHOLD) continue;
                changed++;

                float dx = gx - cx;
                float dy = gy - cy;
                float dist = (float)Math.sqrt(dx * dx + dy * dy);
                if (dist < minR || dist > maxR) continue;

                float closeness = 1f - (dist / maxR);
                float w = (d / 255f) * (0.35f + 2.4f * closeness * closeness);
                centerDanger += w;

                if (dx < 0) riskL += w; else riskR += w;
                if (dy < 0) riskU += w; else riskD += w;
            }
        }

        float globalMotion = considered == 0 ? 0f : (changed / (float) considered);
        if (globalMotion > 0.34f) {
            DodgeBus.STATUS.set("Камера/сцена сильно сдвинулась, кадр игнорирую");
            System.arraycopy(curr, 0, prev, 0, curr.length);
            return;
        }

        float dangerScore = centerDanger / 30f;
        long now = System.currentTimeMillis();
        if (dangerScore > 0.62f && now - DodgeBus.lastDecisionMs >= COOLDOWN_MS) {
            float best = riskL;
            DodgeBus.Direction dir = DodgeBus.Direction.LEFT;
            if (riskR < best) { best = riskR; dir = DodgeBus.Direction.RIGHT; }
            if (riskU < best) { best = riskU; dir = DodgeBus.Direction.UP; }
            if (riskD < best) { dir = DodgeBus.Direction.DOWN; }
            DodgeBus.request(dir, dangerScore);
        } else {
            DodgeBus.lastDanger = dangerScore;
            DodgeBus.STATUS.set(
                    "Слежу: danger=" + String.format("%.2f", dangerScore) +
                    " motion=" + String.format("%.2f", globalMotion)
            );
        }

        System.arraycopy(curr, 0, prev, 0, curr.length);
    }
}
