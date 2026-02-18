using Microsoft.EntityFrameworkCore;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Enums;
using TimeClock.Domain.Interfaces;
using TimeClock.Infrastructure.Persistence;

namespace TimeClock.Infrastructure.Persistence.Repositories;

public sealed class TimePunchRepository : ITimePunchRepository
{
    private readonly TimeClockDbContext _db;

    public TimePunchRepository(TimeClockDbContext db)
    {
        _db = db;
    }

    public async Task AddAsync(TimePunch punch, CancellationToken ct)
    {
        _db.TimePunches.Add(punch);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<PunchType?> GetLastPunchTypeAsync(Guid employeeId, CancellationToken ct)
    {
        return await _db.TimePunches
            .Where(x => x.EmployeeId == employeeId)
            .OrderByDescending(x => x.TimestampUtc)
            .Select(x => (PunchType?)x.PunchType)
            .FirstOrDefaultAsync(ct);
    }

    public async Task<bool> ExistsAsync(Guid employeeId, string deviceId, long localSequenceNumber, CancellationToken ct)
    {
        return await _db.TimePunches.AnyAsync(
            x => x.EmployeeId == employeeId
                 && x.DeviceId == deviceId
                 && x.LocalSequenceNumber == localSequenceNumber,
            ct);
    }
}
