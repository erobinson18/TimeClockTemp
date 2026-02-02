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

public class EmployeeStatusService : IEmployeeStatusService
{
    private readonly ITimePunchRepository _repo;

    public EmployeeStatusService(ITimePunchRepository repo)
    {
        _repo = repo;
    }

    public async Task<EmployeeStatusDto> GetStatusAsync(Guid employeeId)
    {
        var latestPunch = await _repo.GetLatestByEmployeeIdAsync(employeeId);
        var isClockedIn = latestPunch != null && latestPunch.PunchType == PunchType.ClockIn;

        return new EmployeeStatusDto
        {
            EmployeeId = employeeId,
            IsClockedIn = isClockedIn
        };
    }
}
