<?php
declare(strict_types=1);

session_start();
header('Content-Type: text/html; charset=utf-8');

function env_value(string $key, ?string $fallback = null): ?string {
    static $values = null;
    if ($values === null) {
        $values = [];
        $file = dirname(__DIR__) . DIRECTORY_SEPARATOR . '.env';
        if (is_readable($file)) {
            foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
                $line = trim($line);
                if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
                [$name, $value] = explode('=', $line, 2);
                $values[trim($name)] = trim($value, " \t\"'");
            }
        }
    }
    $value = getenv($key);
    if ($value === false || $value === '') $value = $values[$key] ?? false;
    return ($value === false || $value === '') ? $fallback : $value;
}

function database(): PDO {
    static $pdo = null;
    if ($pdo instanceof PDO) return $pdo;
    $dsn = 'mysql:host=' . env_value('DB_HOST', 'localhost')
        . ';port=' . env_value('DB_PORT', '3306')
        . ';dbname=' . env_value('DB_NAME', '')
        . ';charset=utf8mb4';
    $pdo = new PDO($dsn, env_value('DB_USER', ''), env_value('DB_PASS', ''), [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    return $pdo;
}

function e(?string $value): string {
    return htmlspecialchars($value ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(24));
$message = null;
$messageType = 'success';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (!hash_equals($_SESSION['csrf'], (string)($_POST['csrf'] ?? ''))) {
            throw new RuntimeException('လုံခြုံရေး token မမှန်ပါ။ Page ကို refresh လုပ်ပြီး ထပ်ကြိုးစားပါ။');
        }

        $action = (string)($_POST['action'] ?? '');
        if ($action === 'logout') {
            unset($_SESSION['admin_token']);
            header('Location: ' . strtok($_SERVER['REQUEST_URI'] ?? 'admin.php', '?'));
            exit;
        }

        if ($action === 'login') {
            $token = trim((string)($_POST['token'] ?? ''));
            $expected = env_value('ADMIN_API_TOKEN', '');
            if ($expected === '' || $token === '' || !hash_equals($expected, $token)) {
                throw new RuntimeException('Admin Token မမှန်ပါ။');
            }
            session_regenerate_id(true);
            $_SESSION['admin_token'] = $token;
            $_SESSION['csrf'] = bin2hex(random_bytes(24));
            header('Location: ' . strtok($_SERVER['REQUEST_URI'] ?? 'admin.php', '?'));
            exit;
        }

        if (!isset($_SESSION['admin_token'])) throw new RuntimeException('အရင် Login ဝင်ပါ။');
        $expected = env_value('ADMIN_API_TOKEN', '');
        if ($expected === '' || !hash_equals($expected, (string)$_SESSION['admin_token'])) {
            unset($_SESSION['admin_token']);
            throw new RuntimeException('Admin Token သက်တမ်းမမှန်ပါ။');
        }

        if ($action === 'publish') {
            $title = trim((string)($_POST['title'] ?? ''));
            $body = trim((string)($_POST['message'] ?? ''));
            $type = (string)($_POST['type'] ?? 'info');
            if ($title === '' || mb_strlen($title) > 160) throw new RuntimeException('Title ဖြည့်ပါ (အများဆုံး 160 စာလုံး)။');
            if ($body === '' || mb_strlen($body) > 5000) throw new RuntimeException('Message ဖြည့်ပါ (အများဆုံး 5000 စာလုံး)။');
            if (!in_array($type, ['info', 'update', 'alert'], true)) throw new RuntimeException('Notification type မမှန်ပါ။');
            $stmt = database()->prepare('INSERT INTO notifications (title, message, type, is_published) VALUES (:title, :message, :type, 1)');
            $stmt->execute(['title' => $title, 'message' => $body, 'type' => $type]);
            $message = 'Notification ပို့ပြီးပါပြီ။ App က နောက်တစ်ကြိမ်ဖွင့်/စစ်တဲ့အခါ မြင်ရပါမယ်။';
        }
    } catch (Throwable $error) {
        $message = $error->getMessage();
        $messageType = 'error';
    }
}

$loggedIn = isset($_SESSION['admin_token']);
$recent = [];
if ($loggedIn) {
    try {
        $recent = database()->query('SELECT id, title, message, type, created_at FROM notifications ORDER BY created_at DESC LIMIT 20')->fetchAll();
    } catch (Throwable $error) {
        $message = 'Database ကို ဖတ်မရသေးပါ။ .env နဲ့ table ကို စစ်ပါ။';
        $messageType = 'error';
    }
}
?><!doctype html>
<html lang="my">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>YBS AI · Notification Admin</title>
<style>
:root{font-family:system-ui,-apple-system,"Noto Sans Myanmar",sans-serif;color:#172033;background:#f4f7fb;--blue:#2563eb;--ink:#172033;--muted:#64748b;--line:#e2e8f0}
*{box-sizing:border-box}body{margin:0}.wrap{max-width:980px;margin:auto;padding:24px 16px 56px}.top{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:22px}.brand{display:flex;align-items:center;gap:12px}.logo{width:46px;height:46px;border-radius:14px;background:#172033;color:#fff;display:grid;place-items:center;font-size:22px}.brand h1{font-size:21px;margin:0}.brand p{font-size:12px;color:var(--muted);margin:3px 0 0}.card{background:#fff;border:1px solid var(--line);border-radius:20px;padding:22px;box-shadow:0 8px 24px #0f172a0b;margin-bottom:18px}.login{max-width:480px;margin:80px auto}.title{font-size:17px;font-weight:800;margin:0 0 5px}.sub{color:var(--muted);font-size:13px;margin:0 0 18px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.full{grid-column:1/-1}label{display:block;font-size:13px;font-weight:700;margin:0 0 7px}input,textarea,select{width:100%;border:1px solid #cbd5e1;border-radius:12px;padding:12px 13px;font:inherit;font-size:14px;background:#fff;color:var(--ink)}textarea{min-height:145px;resize:vertical}input:focus,textarea:focus,select:focus{outline:3px solid #2563eb22;border-color:var(--blue)}button{border:0;border-radius:12px;padding:12px 18px;font:inherit;font-weight:800;cursor:pointer}.primary{background:var(--blue);color:white}.secondary{background:#eef2ff;color:#1d4ed8}.danger{background:#fff1f2;color:#be123c}.top form{margin:0}.alert{padding:13px 15px;border-radius:12px;margin-bottom:16px;font-size:13px}.success{background:#ecfdf5;color:#047857;border:1px solid #a7f3d0}.error{background:#fff1f2;color:#be123c;border:1px solid #fecdd3}.actions{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-top:16px}.hint{color:var(--muted);font-size:12px}.item{padding:15px 0;border-bottom:1px solid var(--line)}.item:last-child{border-bottom:0}.item-head{display:flex;align-items:center;gap:9px}.item h3{font-size:14px;margin:0;flex:1}.item p{font-size:13px;white-space:pre-wrap;line-height:1.65;margin:8px 0 4px;color:#334155}.date{font-size:11px;color:var(--muted)}.tag{font-size:11px;border-radius:99px;padding:4px 9px;font-weight:800}.tag-info{background:#eff6ff;color:#1d4ed8}.tag-update{background:#ecfdf5;color:#047857}.tag-alert{background:#fff1f2;color:#be123c}.empty{padding:18px;text-align:center;color:var(--muted);font-size:13px}@media(max-width:640px){.wrap{padding:15px 12px 40px}.top{align-items:flex-start}.brand h1{font-size:18px}.card{padding:17px;border-radius:16px}.grid{grid-template-columns:1fr}.full{grid-column:auto}.actions{align-items:stretch;flex-direction:column}.actions button{width:100%}}
</style>
</head>
<body>
<div class="wrap">
<?php if (!$loggedIn): ?>
  <div class="card login">
    <div class="brand"><div class="logo">🔔</div><div><h1>YBS AI Admin</h1><p>Notification ပို့ရန် ဝင်ရောက်ပါ</p></div></div>
    <?php if ($message): ?><div class="alert <?=e($messageType)?>"><?=e($message)?></div><?php endif; ?>
    <form method="post" autocomplete="off" style="margin-top:22px">
      <input type="hidden" name="csrf" value="<?=e($_SESSION['csrf'])?>">
      <input type="hidden" name="action" value="login">
      <label for="token">Admin Token</label>
      <input id="token" type="password" name="token" required placeholder="Admin Token ထည့်ပါ">
      <button class="primary" type="submit" style="width:100%;margin-top:14px">Login ဝင်မည်</button>
    </form>
  </div>
<?php else: ?>
  <header class="top"><div class="brand"><div class="logo">🔔</div><div><h1>YBS AI Notification Admin</h1><p>App အသုံးပြုသူများထံ Notification ပို့ရန်</p></div></div><form method="post"><input type="hidden" name="csrf" value="<?=e($_SESSION['csrf'])?>"><input type="hidden" name="action" value="logout"><button class="danger" type="submit">Logout</button></form></header>
  <?php if ($message): ?><div class="alert <?=e($messageType)?>"><?=e($message)?></div><?php endif; ?>
  <section class="card">
    <h2 class="title">Notification အသစ်ပို့မည်</h2><p class="sub">ခေါင်းစဉ်နဲ့ စာသားရေးပြီး App ထဲကို ပို့နိုင်ပါတယ်။</p>
    <form method="post">
      <input type="hidden" name="csrf" value="<?=e($_SESSION['csrf'])?>"><input type="hidden" name="action" value="publish">
      <div class="grid">
        <div><label for="title">ခေါင်းစဉ်</label><input id="title" name="title" maxlength="160" required placeholder="ဥပမာ - YBS 117 Update"></div>
        <div><label for="type">အမျိုးအစား</label><select id="type" name="type"><option value="info">Info · အချက်အလက်</option><option value="update">Update · ပြောင်းလဲမှု</option><option value="alert">Alert · သတိပေးချက်</option></select></div>
        <div class="full"><label for="message">စာသား</label><textarea id="message" name="message" maxlength="5000" required placeholder="အသုံးပြုသူများ ဖတ်ရမည့်စာသားကို ရေးပါ..."></textarea></div>
      </div>
      <div class="actions"><span class="hint">အများဆုံး စာလုံး ၅,၀၀၀ · Notification ကို App က API မှ ပြန်ဖတ်ပါမယ်။</span><button class="primary" type="submit">🔔 Notification ပို့မည်</button></div>
    </form>
  </section>
  <section class="card"><h2 class="title">နောက်ဆုံးပို့ထားသော Notifications</h2><p class="sub">နောက်ဆုံး ၂၀ ခု</p>
  <?php if (!$recent): ?><div class="empty">Notification မရှိသေးပါ။</div><?php else: foreach ($recent as $item): ?><article class="item"><div class="item-head"><span class="tag tag-<?=e((string)$item['type'])?>"><?=e(strtoupper((string)$item['type']))?></span><h3><?=e((string)$item['title'])?></h3><span class="date"><?=e((string)$item['created_at'])?></span></div><p><?=e((string)$item['message'])?></p></article><?php endforeach; endif; ?>
  </section>
<?php endif; ?>
</div>
</body>
</html>
