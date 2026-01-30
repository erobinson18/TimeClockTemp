using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Application.DTOs;

public class VerifyEmployeeResultDto
{
    public bool IsValid { get; set; }
    public string? EmployeeId { get; set; }
    public string? DisplayName { get; set; }
}
