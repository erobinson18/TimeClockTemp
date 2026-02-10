using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace TimeClock.Application.DTOs;

// Application-layer request DTO (what the service expects)
public sealed class VerifyEmployeeRequestDto
{
    public string EmployeeNumber { get; set; } = string.Empty;
}

