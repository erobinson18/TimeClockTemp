using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TimeClock.Infrastructure.Persistence;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/monitoring")]
public class MonitoringController : ControllerBase
{
    private readonly TimeClockDbContext _db;

    public MonitoringController(TimeClockDbContext db)
    {
        _db = db;
    }

    // ONE endpoint = one "monitoring screen" in Swagger
    [HttpGet("screen")]
    public async Task<IActionResult> Screen([FromQuery] int take = 15)
    {
        take = Math.Clamp(take, 1, 100);

        var serverTimeUtc = DateTime.UtcNow;
        var todayUtc = serverTimeUtc.Date;

        // DB reachable (works for LocalDB + Cloud SQL)
        var dbReachable = await _db.Database.CanConnectAsync();

        // Summary counts (read-only, non-tracking)
        var totalPunches = await _db.TimePunches.AsNoTracking().CountAsync();
        var punchesTodayUtc = await _db.TimePunches.AsNoTracking()
            .CountAsync(p => p.TimestampUtc >= todayUtc);

        // Recent punches (project location safely; do NOT return owned object directly)
        var recent = await _db.TimePunches.AsNoTracking()
            .OrderByDescending(p => p.TimestampUtc)
            .Take(take)
            .Select(p => new
            {
                p.Id,
                p.EmployeeId,
                p.PunchType,
                p.DeviceType,
                p.DeviceId,
                p.LocalSequenceNumber,
                p.TimestampUtc,
                Latitude = p.Location != null ? p.Location.Latitude : (double?)null,
                Longitude = p.Location != null ? p.Location.Longitude : (double?)null
            })
            .ToListAsync();

        return Ok(new
        {
            serverTimeUtc,
            databaseReachable = dbReachable,
            totals = new
            {
                totalPunches,
                punchesTodayUtc
            },
            recentPunches = recent
        });
    }
}
