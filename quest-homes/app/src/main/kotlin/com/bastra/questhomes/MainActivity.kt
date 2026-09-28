package com.bastra.questhomes

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.flyfishxu.kadb.Kadb
import com.flyfishxu.kadb.cert.KadbCert
import com.flyfishxu.kadb.cert.OkioFilePrivateKeyStore
import kotlinx.coroutines.runBlocking
import okio.Path.Companion.toPath
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : Activity() {
    companion object {
        private const val TARGET_HOME = "com.meta.shell.env.footprint.haven2025"
        private const val COMMUNITY_RELEASE =
            "https://api.github.com/repos/nikitat21/Quest-Home-Switcher/releases/tags/community-v2.0.0"
        private const val REQUEST_IMPORT = 700
    }

    data class HomeItem(
        val id: String,
        val name: String,
        val url: String,
        val size: Long
    )

    private val worker = Executors.newSingleThreadExecutor()
    private var adb: Kadb? = null
    private val homes = mutableListOf<HomeItem>()

    private lateinit var status: TextView
    private lateinit var hostInput: EditText
    private lateinit var pairPortInput: EditText
    private lateinit var connectPortInput: EditText
    private lateinit var pairCodeInput: EditText
    private lateinit var searchInput: EditText
    private lateinit var catalogBox: LinearLayout

    private val prefs by lazy { getSharedPreferences("quest_homes", MODE_PRIVATE) }
    private val backupFile by lazy { File(filesDir, "backup/haven2025-original.apk") }
    private val downloadDir by lazy { File(filesDir, "homes").apply { mkdirs() } }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        runCatching {
            val keyPath = File(filesDir, "adb/adbkey.pem")
            keyPath.parentFile?.mkdirs()
            KadbCert.configure(OkioFilePrivateKeyStore(keyPath.absolutePath.toPath()))
            KadbCert.ensureReady()
        }.onFailure {
            // Pairing UI can still render; the actual error is shown when Pair is pressed.
        }

        setContentView(buildUi())
        restoreSettings()
        refreshBackupLabel()
        loadCatalog()
    }

    override fun onDestroy() {
        runCatching { adb?.close() }
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun buildUi(): View {
        val scroll = ScrollView(this)
        scroll.setBackgroundColor(Color.rgb(12, 15, 20))

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(18), dp(22), dp(30))
        }
        scroll.addView(root, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        root.addView(TextView(this).apply {
            text = "Quest Homes"
            textSize = 28f
            setTextColor(Color.WHITE)
        })

        root.addView(TextView(this).apply {
            text = "Кастомные Meta Quest Home прямо на шлеме. Телефон/ПК сервером не нужен."
            textSize = 15f
            setTextColor(Color.rgb(180, 190, 205))
            setPadding(0, dp(4), 0, dp(14))
        })

        status = TextView(this).apply {
            text = "ADB: не подключён"
            textSize = 15f
            setTextColor(Color.rgb(255, 205, 95))
            setPadding(dp(12), dp(10), dp(12), dp(10))
            setBackgroundColor(Color.rgb(28, 34, 44))
        }
        root.addView(status, match())

        root.addView(sectionTitle("1. Wireless ADB"))

        hostInput = input("Host / IP", "127.0.0.1")
        pairPortInput = input("Pairing port", "")
        pairCodeInput = input("6-значный код", "")
        connectPortInput = input("Connection port", "")

        root.addView(hostInput, match())
        root.addView(pairPortInput, match())
        root.addView(pairCodeInput, match())
        root.addView(connectPortInput, match())

        val adbButtons = horizontal()
        adbButtons.addView(button("Открыть настройки ADB") {
            runCatching {
                startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
            }.onFailure {
                setStatus("Не получилось открыть Developer settings: " + it.message, true)
            }
        }, weight())
        adbButtons.addView(button("Pair") { pairDevice() }, weight())
        adbButtons.addView(button("Connect/Test") { connectDevice() }, weight())
        root.addView(adbButtons, match())

        root.addView(TextView(this).apply {
            text = "В Wireless debugging: Pair device with pairing code → сюда Pairing port + код. Connection port указан на основном экране Wireless debugging."
            textSize = 13f
            setTextColor(Color.rgb(150, 160, 175))
            setPadding(0, dp(6), 0, dp(6))
        })

        root.addView(sectionTitle("2. Защита / восстановление"))

        val backupButtons = horizontal()
        backupButtons.addView(button("Backup official Home") { backupOfficial() }, weight())
        backupButtons.addView(button("Restore original") { restoreOriginal() }, weight())
        root.addView(backupButtons, match())

        root.addView(sectionTitle("3. Свой APK"))

        val importButtons = horizontal()
        importButtons.addView(button("Выбрать APK") { chooseApk() }, weight())
        importButtons.addView(button("Проверить текущий Home") { inspectCurrentHome() }, weight())
        root.addView(importButtons, match())

        root.addView(sectionTitle("4. Каталог"))

        searchInput = input("Поиск по 250 community homes", "")
        root.addView(searchInput, match())
        searchInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                renderCatalog()
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        root.addView(button("Обновить каталог") { loadCatalog() }, match())

        catalogBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        root.addView(catalogBox, match())

        root.addView(TextView(this).apply {
            text = "Источник community APK: публичный release feed Quest Home Switcher. Права на сами Home остаются у их авторов."
            textSize = 12f
            setTextColor(Color.rgb(115, 125, 140))
            setPadding(0, dp(16), 0, 0)
        })

        return scroll
    }

    private fun restoreSettings() {
        hostInput.setText(prefs.getString("host", "127.0.0.1"))
        pairPortInput.setText(prefs.getString("pairPort", ""))
        connectPortInput.setText(prefs.getString("connectPort", ""))
    }

    private fun saveSettings() {
        prefs.edit()
            .putString("host", hostInput.text.toString().trim())
            .putString("pairPort", pairPortInput.text.toString().trim())
            .putString("connectPort", connectPortInput.text.toString().trim())
            .apply()
    }

    private fun pairDevice() {
        val host = hostInput.text.toString().trim().ifBlank { "127.0.0.1" }
        val port = pairPortInput.text.toString().trim().toIntOrNull()
        val code = pairCodeInput.text.toString().trim()
        if (port == null || code.length != 6) {
            setStatus("Нужны Pairing port и 6-значный код.", true)
            return
        }
        saveSettings()
        setBusy("Pairing…")
        worker.execute {
            try {
                runBlocking { Kadb.pair(host, port, code, "Quest Homes") }
                setStatus("Pairing OK. Теперь Connect/Test.", false)
            } catch (e: Throwable) {
                setStatus("Pairing error: " + shortError(e), true)
            }
        }
    }

    private fun connectDevice() {
        val host = hostInput.text.toString().trim().ifBlank { "127.0.0.1" }
        val port = connectPortInput.text.toString().trim().toIntOrNull()
        if (port == null) {
            setStatus("Укажи Connection port из Wireless debugging.", true)
            return
        }
        saveSettings()
        setBusy("ADB connect…")
        worker.execute {
            try {
                runCatching { adb?.close() }
                val client = Kadb.create(host, port, connectTimeout = 8000, socketTimeout = 20000)
                val ping = client.shell("echo QUEST_HOMES_OK").allOutput.trim()
                check(ping.contains("QUEST_HOMES_OK")) { "ADB не ответил" }
                adb = client
                runCatching {
                    client.shell("pm grant " + packageName + " android.permission.WRITE_SECURE_SETTINGS")
                }
                setStatus("ADB подключён ✓", false)
            } catch (e: Throwable) {
                adb = null
                setStatus("ADB error: " + shortError(e), true)
            }
        }
    }

    private fun currentAdb(): Kadb {
        val client = adb ?: error("Сначала Connect/Test.")
        val ping = client.shell("echo ok").allOutput.trim()
        check(ping == "ok") { "ADB соединение потеряно. Нажми Connect/Test." }
        return client
    }

    private fun backupOfficial() {
        setBusy("Делаю backup Haven2025…")
        worker.execute {
            try {
                val client = currentAdb()
                val paths = packagePaths(client)
                check(paths.isNotEmpty()) { "Haven2025 не найден." }

                val source = paths.firstOrNull { it.endsWith("/base.apk") } ?: paths.first()
                backupFile.parentFile?.mkdirs()
                client.pull(backupFile, source)
                check(backupFile.exists() && backupFile.length() > 100_000) {
                    "Backup получился пустым."
                }
                prefs.edit()
                    .putString("backupSource", source)
                    .putLong("backupSize", backupFile.length())
                    .apply()
                refreshBackupLabel()
                setStatus("Backup готов: " + humanSize(backupFile.length()), false)
            } catch (e: Throwable) {
                setStatus("Backup error: " + shortError(e), true)
            }
        }
    }

    private fun inspectCurrentHome() {
        setBusy("Проверяю Haven2025…")
        worker.execute {
            try {
                val client = currentAdb()
                val paths = packagePaths(client)
                if (paths.isEmpty()) {
                    setStatus("Haven2025 сейчас не установлен.", true)
                } else {
                    setStatus("Haven2025 установлен: " + paths.first(), false)
                }
            } catch (e: Throwable) {
                setStatus("Check error: " + shortError(e), true)
            }
        }
    }

    private fun restoreOriginal() {
        if (!backupFile.exists()) {
            setStatus("Нет backup. Сначала Backup official Home.", true)
            return
        }
        setBusy("Восстанавливаю оригинальный Haven2025…")
        worker.execute {
            try {
                val client = currentAdb()
                uninstallTarget(client)
                client.install(backupFile, "-r", "-d")
                check(packagePaths(client).isNotEmpty()) { "После restore пакет не появился." }
                reloadHome(client)
                setStatus("Оригинальный Home восстановлен ✓", false)
            } catch (e: Throwable) {
                setStatus("Restore error: " + shortError(e), true)
            }
        }
    }

    private fun chooseApk() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/vnd.android.package-archive"
        }
        startActivityForResult(intent, REQUEST_IMPORT)
    }

    @Deprecated("Deprecated in Android SDK but supported for the Quest target.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_IMPORT || resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        setBusy("Импорт APK…")
        worker.execute {
            try {
                val dst = File(downloadDir, "import-" + System.currentTimeMillis() + ".apk")
                contentResolver.openInputStream(uri).use { input ->
                    checkNotNull(input) { "Не удалось открыть APK." }
                    FileOutputStream(dst).use { out -> input.copyTo(out) }
                }
                applyHome(dst, "Imported APK")
            } catch (e: Throwable) {
                setStatus("Import error: " + shortError(e), true)
            }
        }
    }

    private fun loadCatalog() {
        setBusy("Загружаю каталог…")
        worker.execute {
            try {
                val json = httpGet(COMMUNITY_RELEASE)
                val root = JSONObject(json)
                val assets = root.getJSONArray("assets")
                val parsed = ArrayList<HomeItem>()
                for (i in 0 until assets.length()) {
                    val a = assets.getJSONObject(i)
                    val fileName = a.optString("name")
                    if (!fileName.endsWith("-NoRoot.apk", ignoreCase = true)) continue
                    val url = a.optString("browser_download_url")
                    if (!url.startsWith("https://")) continue
                    val pretty = fileName
                        .removePrefix("Community-Home-")
                        .removeSuffix("-NoRoot.apk")
                        .replace('-', ' ')
                    parsed += HomeItem(
                        id = safeId(fileName),
                        name = pretty,
                        url = url,
                        size = a.optLong("size", 0L)
                    )
                }
                parsed.sortBy { it.name.lowercase(Locale.ROOT) }
                homes.clear()
                homes.addAll(parsed)
                runOnUiThread { renderCatalog() }
                setStatus("Каталог: " + homes.size + " NoRoot Homes ✓", false)
            } catch (e: Throwable) {
                setStatus("Catalog error: " + shortError(e), true)
            }
        }
    }

    private fun renderCatalog() {
        if (!::catalogBox.isInitialized) return
        val q = if (::searchInput.isInitialized) {
            searchInput.text.toString().trim().lowercase(Locale.ROOT)
        } else {
            ""
        }

        catalogBox.removeAllViews()
        val filtered = homes.asSequence()
            .filter { q.isBlank() || it.name.lowercase(Locale.ROOT).contains(q) }
            .take(60)
            .toList()

        if (filtered.isEmpty()) {
            catalogBox.addView(TextView(this).apply {
                text = if (homes.isEmpty()) "Каталог ещё грузится…" else "Ничего не найдено."
                setTextColor(Color.LTGRAY)
                setPadding(0, dp(12), 0, dp(12))
            })
            return
        }

        for (home in filtered) {
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), dp(10), dp(12), dp(10))
                setBackgroundColor(Color.rgb(25, 30, 39))
            }

            card.addView(TextView(this).apply {
                text = home.name
                textSize = 17f
                setTextColor(Color.WHITE)
            })

            card.addView(TextView(this).apply {
                text = if (home.size > 0) humanSize(home.size) else "Community Home"
                textSize = 12f
                setTextColor(Color.rgb(145, 155, 170))
            })

            card.addView(button("Скачать и применить") {
                downloadAndApply(home)
            }, match())

            val p = match()
            p.setMargins(0, dp(7), 0, 0)
            catalogBox.addView(card, p)
        }

        if (homes.size > filtered.size && q.isBlank()) {
            catalogBox.addView(TextView(this).apply {
                text = "Показаны первые 60. Введи название в поиск — каталог содержит " + homes.size + "."
                textSize = 12f
                setTextColor(Color.GRAY)
                setPadding(0, dp(8), 0, 0)
            })
        }
    }

    private fun downloadAndApply(home: HomeItem) {
        setBusy("Скачиваю " + home.name + "…")
        worker.execute {
            try {
                val dst = File(downloadDir, home.id + ".apk")
                downloadFile(home.url, dst) { done, total ->
                    val label = if (total > 0) {
                        val pct = (done * 100L / total).coerceIn(0L, 100L)
                        "Скачиваю " + home.name + "… " + pct + "%"
                    } else {
                        "Скачиваю " + home.name + "… " + humanSize(done)
                    }
                    setBusy(label)
                }
                applyHome(dst, home.name)
            } catch (e: Throwable) {
                setStatus("Download/apply error: " + shortError(e), true)
            }
        }
    }

    private fun applyHome(apk: File, label: String) {
        check(apk.exists() && apk.length() > 10_000) { "APK пустой." }

        val archivePackage = packageManager
            .getPackageArchiveInfo(apk.absolutePath, 0)
            ?.packageName
            ?: error("Android не смог прочитать manifest APK.")

        check(archivePackage == TARGET_HOME) {
            "Этот APK не Haven2025 NoRoot. package=" + archivePackage
        }

        val client = currentAdb()

        if (!backupFile.exists()) {
            val paths = packagePaths(client)
            check(paths.isNotEmpty()) {
                "Перед первой заменой нужен оригинальный Haven2025 для backup."
            }
            setBusy("Первый запуск: сохраняю оригинальный Haven2025…")
            val source = paths.firstOrNull { it.endsWith("/base.apk") } ?: paths.first()
            backupFile.parentFile?.mkdirs()
            client.pull(backupFile, source)
            check(backupFile.length() > 100_000) { "Не удалось создать безопасный backup." }
            prefs.edit().putString("backupSource", source).putLong("backupSize", backupFile.length()).apply()
            refreshBackupLabel()
        }

        setBusy("Устанавливаю " + label + "…")
        uninstallTarget(client)

        try {
            client.install(apk, "-r", "-d")
        } catch (installError: Throwable) {
            // Never leave the headset without Haven if the replacement fails.
            runCatching {
                client.install(backupFile, "-r", "-d")
            }
            throw IllegalStateException(
                "Custom Home не установился; оригинал восстановлен. " + shortError(installError)
            )
        }

        check(packagePaths(client).isNotEmpty()) {
            runCatching { client.install(backupFile, "-r", "-d") }
            "После установки Haven2025 не найден."
        }

        reloadHome(client)
        prefs.edit().putString("lastHome", label).apply()
        setStatus("Активирован: " + label + " ✓", false)
    }

    private fun uninstallTarget(client: Kadb) {
        val first = client.shell("pm uninstall --user 0 " + TARGET_HOME).allOutput.trim()
        if (!first.contains("Success", ignoreCase = true)) {
            val second = client.shell("pm uninstall " + TARGET_HOME).allOutput.trim()
            if (!second.contains("Success", ignoreCase = true) &&
                packagePaths(client).isNotEmpty()
            ) {
                error("Не удалось удалить текущий Haven2025: " + first + " / " + second)
            }
        }
    }

    private fun reloadHome(client: Kadb) {
        runCatching { client.shell("am force-stop com.oculus.vrshell") }
        runCatching {
            client.shell(
                "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
            )
        }
    }

    private fun packagePaths(client: Kadb): List<String> {
        val out = client.shell("pm path " + TARGET_HOME).allOutput
        return out.lineSequence()
            .map { it.trim() }
            .filter { it.startsWith("package:") }
            .map { it.removePrefix("package:") }
            .filter { it.isNotBlank() }
            .toList()
    }

    private fun refreshBackupLabel() {
        runOnUiThread {
            val suffix = if (backupFile.exists()) {
                " | backup: " + humanSize(backupFile.length())
            } else {
                " | backup: нет"
            }
            val current = if (::status.isInitialized) status.text.toString() else "ADB: не подключён"
            if (!current.contains("| backup:")) {
                status.text = current + suffix
            }
        }
    }

    private fun httpGet(url: String): String {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.instanceFollowRedirects = true
        conn.connectTimeout = 12_000
        conn.readTimeout = 25_000
        conn.setRequestProperty("User-Agent", "QuestHomes/0.1")
        conn.setRequestProperty("Accept", "application/vnd.github+json")
        return try {
            check(conn.responseCode in 200..299) { "HTTP " + conn.responseCode }
            conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    private fun downloadFile(
        url: String,
        dst: File,
        progress: (Long, Long) -> Unit
    ) {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.instanceFollowRedirects = true
        conn.connectTimeout = 15_000
        conn.readTimeout = 60_000
        conn.setRequestProperty("User-Agent", "QuestHomes/0.1")
        dst.parentFile?.mkdirs()
        try {
            check(conn.responseCode in 200..299) { "HTTP " + conn.responseCode }
            val total = conn.contentLengthLong
            conn.inputStream.use { input ->
                FileOutputStream(dst).use { out ->
                    val buffer = ByteArray(128 * 1024)
                    var done = 0L
                    var lastUi = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        out.write(buffer, 0, n)
                        done += n
                        val now = System.currentTimeMillis()
                        if (now - lastUi > 350) {
                            progress(done, total)
                            lastUi = now
                        }
                    }
                    progress(done, total)
                }
            }
            check(dst.length() > 10_000) { "Скачанный файл слишком маленький." }
        } finally {
            conn.disconnect()
        }
    }

    private fun safeId(name: String): String {
        return sha256(name.toByteArray()).take(20)
    }

    private fun sha256(bytes: ByteArray): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { "%02x".format(it) }
    }

    private fun setBusy(text: String) = setStatus(text, false)

    private fun setStatus(text: String, error: Boolean) {
        runOnUiThread {
            val backup = if (backupFile.exists()) {
                " | backup: " + humanSize(backupFile.length())
            } else {
                " | backup: нет"
            }
            status.text = text + backup
            status.setTextColor(
                if (error) Color.rgb(255, 115, 115)
                else Color.rgb(120, 225, 150)
            )
        }
    }

    private fun shortError(t: Throwable): String {
        var cur: Throwable? = t
        var last = t
        var depth = 0
        while (cur != null && depth < 6) {
            last = cur
            cur = cur.cause
            depth++
        }
        return (last.message ?: t.message ?: t.javaClass.simpleName).take(500)
    }

    private fun humanSize(bytes: Long): String {
        if (bytes < 1024) return bytes.toString() + " B"
        val kb = bytes / 1024.0
        if (kb < 1024) return String.format(Locale.US, "%.1f KB", kb)
        val mb = kb / 1024.0
        if (mb < 1024) return String.format(Locale.US, "%.1f MB", mb)
        return String.format(Locale.US, "%.2f GB", mb / 1024.0)
    }

    private fun sectionTitle(text: String) = TextView(this).apply {
        this.text = text
        textSize = 18f
        setTextColor(Color.rgb(120, 190, 255))
        setPadding(0, dp(18), 0, dp(7))
    }

    private fun input(hint: String, value: String) = EditText(this).apply {
        this.hint = hint
        setHintTextColor(Color.rgb(110, 120, 135))
        setTextColor(Color.WHITE)
        setText(value)
        setSingleLine(true)
        setPadding(dp(12), dp(9), dp(12), dp(9))
        setBackgroundColor(Color.rgb(28, 34, 44))
    }

    private fun button(text: String, click: () -> Unit) = Button(this).apply {
        this.text = text
        isAllCaps = false
        setTextColor(Color.WHITE)
        setBackgroundColor(Color.rgb(45, 90, 150))
        setOnClickListener { click() }
    }

    private fun horizontal() = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    private fun match() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
    ).apply {
        setMargins(0, dp(4), 0, dp(4))
    }

    private fun weight() = LinearLayout.LayoutParams(
        0,
        ViewGroup.LayoutParams.WRAP_CONTENT,
        1f
    ).apply {
        setMargins(dp(3), dp(3), dp(3), dp(3))
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
