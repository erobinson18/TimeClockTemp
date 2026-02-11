using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Commands;
using TimeClock.Application.Interfaces;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Interfaces;

namespace TimeClock.Application.Services;

public class TimePunchService : ITimePunchService
{
    private readonly ITimePunchRepository _repository;
    private readonly TimeClockDbContext _db;

    public TimePunchService(TimeClockDbContext db)
    {
        _db = db;
    }

    public TimePunchService(ITimePunchRepository repository)
    {
        _repository = repository;
    }

    public async Task CreateAsync(CreateTimePunchCommand command)
    {
        var punch = new TimePunch(
            command.EmployeeId,
            command.PunchType,
            command.DeviceType,
            command.DeviceId,
            command.LocalSequenceNumber,
            command.Location
        );

        await _repository.AddAsync(punch);
    }

    public async Task<bool> IsEmployeeClockedInAsync(string employeeId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(employeeId))
            return false;

        var lastPunch = await _db.TimePunches
            .AsNoTracking()
            .Where(p => p.EmployeeId == employeeId)
            .OrderByDescending(p => p.TimestampUtc)
            .ThenByDescending(p => p.LocalSequenceNumber)
            .Select(p => new { p.PunchType })
            .FirestOrDefaultAsync(ct);

        if (lastPunch == null)
            return false;

        return lastPunch.PunchType == PunchType.ClockIn
            || lastPunch.PunchType == 1;
    }
}
