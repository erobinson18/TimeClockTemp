using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Application.DTOs;

public class EmployeeStatusDto
{
    public string EmployeeId { get; set; } = string.Empty;
    public bool IsClockedIn { get; set; }
}
