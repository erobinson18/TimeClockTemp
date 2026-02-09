using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Application.Integrations.Models;

public sealed class VerifiedEmployee
{
    public Guid EmployeeId { get; init; }
    public string EmployeeNumber { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
}
