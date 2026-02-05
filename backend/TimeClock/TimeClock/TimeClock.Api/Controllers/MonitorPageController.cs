using Microsoft.AspNetCore.Mvc;

namespace TimeClock.Api.Controllers;

[ApiController]
public class MonitorPageController : ControllerBase
{
    [HttpGet("/monitor")]
    public ContentResult MonitorPage()
    {
        const string html = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>TimeClock Monitoring</title>
<style>
  body { font-family: system-ui, Arial; margin: 16px; }
  header { display:flex; gap:16px; align-items:center; justify-content:space-between; }
  .muted { opacity: 0.7; }
  .row { display:flex; gap:12px; flex-wrap:wrap; margin: 12px 0; }
  .card { border: 1px solid #ddd; border-radius: 12px; padding: 10px 12px; min-width: 240px; }
  .ok { color: #0a7d33; font-weight: 600; }
  .bad { color: #b00020; font-weight: 600; }
  table { width: 100%; border-collapse: collapse; margin-top: 12px; }
  th, td { text-align:left; padding: 10px 8px; border-bottom: 1px solid #eee; font-size: 14px; }
  th { background: #fafafa; position: sticky; top: 0; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; }
  .wrap { max-width: 1280px; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div>
      <h2 style="margin:0;">TimeClock Monitoring</h2>
      <div class="muted">Auto-refresh every 3 seconds</div>
    </div>
    <div>
      <div id="status" class="ok">Loading…</div>
      <div class="muted" id="last"></div>
    </div>
  </header>

  <div class="row">
    <div class="card">
      <div class="muted">Server Time (UTC)</div>
      <div id="serverTime">—</div>
    </div>
    <div class="card">
      <div class="muted">Database Reachable</div>
      <div id="dbReachable">—</div>
    </div>
    <div class="card">
      <div class="muted">Total Punches</div>
      <div id="totalPunches">—</div>
    </div>
    <div class="card">
      <div class="muted">Punches Today (UTC)</div>
      <div id="punchesToday">—</div>
    </div>
  </div>

  <div class="muted">Source: <code id="endpoint"></code></div>

  <table>
    <thead>
      <tr>
        <th>Timestamp (UTC)</th>
        <th>EmployeeId</th>
        <th>PunchType</th>
        <th>Device</th>
        <th>Seq</th>
        <th>Lat</th>
        <th>Lon</th>
      </tr>
    </thead>
    <tbody id="rows">
      <tr><td colspan="7">Loading…</td></tr>
    </tbody>
  </table>
</div>

<script>
  const endpoint = "/api/monitoring/screen?take=25";
  document.getElementById("endpoint").textContent = endpoint;

  function fmt(v) {
    if (v === null || v === undefined) return "";
    return String(v);
  }

  function punchTypeLabel(v) {
    if (v === 1) return "CLOCK IN";
    if (v === 2) return "CLOCK OUT";
    return fmt(v);
  }

  async function refresh() {
    try {
      const res = await fetch(endpoint, { cache: "no-store" });
      const json = await res.json();

      const ok = res.ok;
      document.getElementById("status").textContent = ok ? "OK" : ("HTTP " + res.status);
      document.getElementById("status").className = ok ? "ok" : "bad";

      document.getElementById("last").textContent =
        "Last refresh: " + new Date().toLocaleTimeString();

      document.getElementById("serverTime").textContent = fmt(json.serverTimeUtc);

      const db = json.databaseReachable === true;
      const dbEl = document.getElementById("dbReachable");
      dbEl.textContent = db ? "YES" : "NO";
      dbEl.className = db ? "ok" : "bad";

      document.getElementById("totalPunches").textContent =
        fmt(json.totals?.totalPunches);

      document.getElementById("punchesToday").textContent =
        fmt(json.totals?.punchesTodayUtc);

      const punches = json.recentPunches || [];
      const tbody = document.getElementById("rows");

      if (punches.length === 0) {
        tbody.innerHTML = "<tr><td colspan='7'>No punches yet.</td></tr>";
        return;
      }

      tbody.innerHTML = punches.map(p => `
        <tr>
          <td>${fmt(p.timestampUtc)}</td>
          <td><code>${fmt(p.employeeId)}</code></td>
          <td>${punchTypeLabel(p.punchType)}</td>
          <td>${fmt(p.deviceId)} (${fmt(p.deviceType)})</td>
          <td>${fmt(p.localSequenceNumber)}</td>
          <td>${fmt(p.latitude)}</td>
          <td>${fmt(p.longitude)}</td>
        </tr>
      `).join("");

    } catch (e) {
      document.getElementById("status").textContent = "ERROR";
      document.getElementById("status").className = "bad";
      document.getElementById("rows").innerHTML =
        "<tr><td colspan='7'>" + fmt(e) + "</td></tr>";
    }
  }

  refresh();
  setInterval(refresh, 3000);
</script>
</body>
</html>
""";

        return new ContentResult
        {
            ContentType = "text/html; charset=utf-8",
            Content = html,
            StatusCode = 200
        };
    }
}
