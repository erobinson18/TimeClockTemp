using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Application.Integrations.Models;

public sealed class VerifiedEmployee
{
    public string EmployeeId { get; set; } = string.Empty;
    public string EmployeeNumber { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public bool IsClockedIn { get; set; }
}
