using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Application.DTOs;

public sealed class VerifyEmployeeResultDto
{
    public bool IsValid { get; set; }
    public string? EmployeeId { get; set; }     // GUID string
    public string? FullName { get; set; }
    public bool IsClockedIn { get; set; }
}
