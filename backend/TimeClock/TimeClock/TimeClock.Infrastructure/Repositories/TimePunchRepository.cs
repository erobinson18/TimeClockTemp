using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using TimeClock.Domain.Entities;
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

    public async Task AddAsync(TimePunch punch)
    {
        _db.TimePunches.Add(punch);
        await _db.SaveChangesAsync();
    }

    public async Task<int?> GetLastPunchTypeAsync(Guid employeeId, CancellationToken ct)
    {
        var lastPunchType = await _db.TimePunches
            .AsNoTracking()
            .Where(p => p.EmployeeId == employeeId)
            .OrderByDescending(p => p.TimestampUtc)
            .ThenByDescending(p => p.LocalSequenceNumber)
            .Select(p => (int?)p.PunchType)
            .FirstOrDefaultAsync(ct);

        return lastPunchType;
    }
}
