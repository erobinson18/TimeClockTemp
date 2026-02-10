using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Interfaces;
using TimeClock.Application.DTOs;
using TimeClock.Domain.Interfaces;
using TimeClock.Domain.Enums;

namespace TimeClock.Application.Services;

public sealed class EmployeeStatusService : IEmployeeStatusService
{
    private readonly ITimePunchService _timePunchService;

    public EmployeeStatusService(ITimePunchService timePunchService)
    {
        _timePunchService = timePunchService;
    }

    public async Task<StatusResponseDto> GetStatusAsync(string employeeId, CancellationToken ct)
    {
        var isClockedIn = await _timePunchService.IsEmployeeClockedInAsync(employeeId, ct);

        return new StatusResponseDto
        {
            IsClockedIn = isClockedIn
        };
    }
}
