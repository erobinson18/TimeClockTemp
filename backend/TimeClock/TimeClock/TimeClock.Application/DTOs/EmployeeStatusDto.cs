using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Enums;

namespace TimeClock.Application.DTOs;

public sealed class EmployeeStatusDto
{
    public bool IsClockedIn { get; set; }
    public PunchType? LastPunchType { get; set; } //(for debugging)
}
