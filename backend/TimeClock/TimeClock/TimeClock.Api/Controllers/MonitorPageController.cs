using Microsoft.AspNetCore.Mvc;

namespace TimeClock.Api.Controllers;

[ApiController]
public class MonitorPageController : ControllerBase
{
    // This page auto-refreshes and displays the monitoring JSON
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
    header { display:flex; gap:16px; align-items:baseline; }
    .muted { opacity: 0.7; }
    pre { padding: 12px; border: 1px solid #ddd; border-radius: 10px; overflow:auto; }
    .row { display:flex; gap:12px; flex-wrap:wrap; margin: 10px 0; }
    .card { border: 1px solid #ddd; border-radius: 10px; padding: 10px 12px; min-width: 220px; }
  </style>
</head>
<body>
  <header>
    <h2>TimeClock Monitoring</h2>
    <div class="muted" id="status"></div>
  </header>

  <div class="row">
    <div class="card"><div class="muted">Endpoint</div><div id="endpoint"></div></div>
    <div class="card"><div class="muted">Auto-refresh</div><div>Every 3 seconds</div></div>
    <div class="card"><div class="muted">Last refresh</div><div id="last"></div></div>
  </div>

  <pre id="out">Loading...</pre>

<script>
  const endpoint = "/api/monitoring/screen?take=15";
  document.getElementById("endpoint").textContent = endpoint;

  async function refresh() {
    try {
      const res = await fetch(endpoint, { cache: "no-store" });
      const txt = await res.text();
      document.getElementById("out").textContent = txt;
      document.getElementById("status").textContent = res.ok ? "OK" : ("HTTP " + res.status);
      document.getElementById("last").textContent = new Date().toLocaleTimeString();
    } catch (e) {
      document.getElementById("status").textContent = "ERROR";
      document.getElementById("out").textContent = String(e);
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
