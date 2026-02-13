using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Enums;

namespace TimeClock.Domain.Interfaces;

public interface ITimePunchRepository
{
    Task AddAsync(TimePunch punch, CancellationToken ct);
    Task<PunchType?> GetLastPunchTypeAsync(Guid employeeId, CancellationToken ct);
    Task<bool> ExistsAsync(Guid employeeId, string deviceId, long localSequenceNumber, CancellationToken ct);
}
