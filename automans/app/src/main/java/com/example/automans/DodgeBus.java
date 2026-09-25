package com.example.automans;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

public final class DodgeBus {
    public enum Direction { LEFT, RIGHT, UP, DOWN, NONE }

    public static final AtomicBoolean AUTO_ENABLED = new AtomicBoolean(false);
    public static final AtomicReference<String> STATUS = new AtomicReference<>("Ожидание запуска");
    public static volatile long lastDecisionMs = 0L;
    public static volatile Direction lastDirection = Direction.NONE;
    public static volatile float lastDanger = 0f;

    private DodgeBus() {}

    public static void request(Direction direction, float danger) {
        lastDecisionMs = System.currentTimeMillis();
        lastDirection = direction;
        lastDanger = danger;
        STATUS.set("Опасность " + String.format("%.2f", danger) + " → " + direction);

        if (AUTO_ENABLED.get() && direction != Direction.NONE) {
            DodgeAccessibilityService.performDodge(direction);
        }
    }
}
