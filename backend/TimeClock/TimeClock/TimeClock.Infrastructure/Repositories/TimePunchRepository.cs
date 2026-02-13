using Microsoft.EntityFrameworkCore;
using TimeClock.Application.Interfaces;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Enums;
using TimeClock.Domain.Interfaces;
using TimeClock.Infrastructure.Persistence;

namespace TimeClock.Infrastructure.Repositories;

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
            .AsNoTracking()
            .Where(p => p.EmployeeId == employeeId)
            .OrderByDescending(p => p.TimestampUtc)
            .ThenByDescending(p => p.LocalSequenceNumber)
            .Select(p => (PunchType?)p.PunchType)
            .FirstOrDefaultAsync(ct);
    }

    public async Task<bool> ExistsAsync(Guid employeeId, string deviceId, long localSequenceNumber, CancellationToken ct)
    {
        return await _db.TimePunches.AnyAsync(p =>
            p.EmployeeId == employeeId &&
            p.DeviceId == deviceId &&
            p.LocalSequenceNumber == localSequenceNumber,
            ct);
    }
}
