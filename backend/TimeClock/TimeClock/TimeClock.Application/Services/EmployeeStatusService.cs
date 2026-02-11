using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;

namespace TimeClock.Application.Services;

public sealed class EmployeeStatusService : IEmployeeStatusService
{
    private readonly ITimePunchService _punchService;

    public EmployeeStatusService(ITimePunchService punchService)
    {
        _punchService = punchService;
    }

    public Task<bool> IsEmployeeClockedInAsync(string employeeId, CancellationToken ct)
        => _punchService.IsEmployeeClockedInAsync(employeeId, ct);

    public async Task<EmployeeStatusDto> GetStatusAsync(string employeeId, CancellationToken ct)
    {
        var clockedIn = await _punchService.IsEmployeeClockedInAsync(employeeId, ct);

        return new EmployeeStatusDto
        {
            EmployeeId = employeeId,
            IsClockedIn = clockedIn
        };
    }
}
