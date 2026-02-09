using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Enums;

namespace TimeClock.Application.Integrations.Models;

public sealed class EmployeePunchStatus
{
    public Guid EmployeeId { get; init; }
    public bool IsClockedIn { get; init; }
    public PunchType? LastPunchType { get; init; }
    public DateTime? LastPunchUtc { get; init; }
}
