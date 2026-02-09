using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using TimeClock.Application.Integrations;
using TimeClock.Application.Integrations.Models;
using TimeClock.Domain.Enums;
using TimeClock.Infrastructure.Persistence;

namespace TimeClock.Infrastructure.Integrations;

public sealed class EfEmployeeStatusGateway : IEmployeeStatusGateway
{
    private readonly TimeClockDbContext _db;

    public EfEmployeeStatusGateway(TimeClockDbContext db)
    {
               _db = db;

    }

    public async Task<EmployeePunchStatus> GetStatusAsync(Guid employeeId, CancellationToken ct = default)
    {
        var last = await _db.TimePunches
            .Where(p => p.EmployeeId == employeeId)
            .OrderByDescending(p => p.TimestampUtc)
            .FirstOrDefaultAsync(ct);

        if (last is null)
        {
            return new EmployeePunchStatus
            {
                EmployeeId = employeeId,
                IsClockedIn = false,
                LastPunchType = null,
                LastPunchUtc = null
            };
        }

        var isIn = last.PunchType == PunchType.ClockIn;

        return new EmployeePunchStatus
        {
            EmployeeId = employeeId,
            IsClockedIn = isIn,
            LastPunchType = last.PunchType,
            LastPunchUtc = last.TimestampUtc
        };
    }
}
