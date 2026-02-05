using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TimeClock.Infrastructure.Persistence;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MonitoringController : ControllerBase
{
    private readonly TimeClockDbContext _db;
    
    public MonitoringController(TimeClockDbContext db)
    {
        _db = db;
    }

    [HttpGet("db")]
    public async Task<IActionResult> DbHealth()
    {
        var canConnect = await _db.Database.CanConnectAsync();
        return Ok(new { DatabaseConnected = canConnect, serverTimeUtc = DateTime.UtcNow });
    }

[HttpGet("punches/summary")]
    public async Task<IActionResult> PunchSummary()
    {
        var total = await _db.TimePunches.CountAsync();

        var todayUtc = DateTime.UtcNow.Date;
        var today = await _db.TimePunches.CountAsync(p => p.TimestampUtc >= todayUtc);

        var lastPunch = await _db.TimePunches
            .OrderByDescending(p => p.TimestampUtc)
            .Select(p => new
            {
                p.EmployeeId,
                p.PunchType,
                p.DeviceType,
                p.DeviceId,
                p.LocalSequenceNumber,
                p.TimestampUtc,
                p.Location
            })
            .FirstOrDefaultAsync();

        return Ok(new
        {
            totalPunches = total,
            punchesTodayUtc = today,
            lastPunch
        });
    }

    [HttpGet("employees/summary")]
    public async Task<IActionResult> RecentPunches([FromQuery] int take = 25)
    {
        take = Math.Clamp(take, 1, 200);

        var punches = await _db.TimePunches
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
                p.Location
            })
            .ToListAsync();

        return Ok(new
        {
            serverTimeUtc = DateTime.UtcNow,
            returned = punches.Count,
            punches
        });
    }

    [HttpGet("punches/last-by-employee")]
    public async Task<IActionResult> LastPunchByEmployee([FromQuery] int take = 50)
    {
        take = Math.Clamp(take, 1, 500);

        var lastByEmp = await _db.TimePunches
            .GroupBy(p => p.EmployeeId)
            .Select(g => g.OrderByDescending(x => x.TimestampUtc).First())
            .OrderByDescending(p => p.TimestampUtc)
            .Take(take)
            .Select(p => new
            {
                p.EmployeeId,
                p.PunchType,
                p.DeviceId,
                p.LocalSequenceNumber,
                p.TimestampUtc,
            })
            .ToListAsync();

        return Ok(new
        {
            serverTimeUtc = DateTime.UtcNow,
            returned = lastByEmp.Count,
            lastByEmp
        });
    }
}