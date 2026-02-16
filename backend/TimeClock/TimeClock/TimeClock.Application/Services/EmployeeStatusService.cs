using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;
using TimeClock.Domain.Enums;
using TimeClock.Domain.Interfaces;

namespace TimeClock.Application.Services;

public sealed class EmployeeStatusService : IEmployeeStatusService
{
    private readonly ITimePunchRepository _repo;

    public EmployeeStatusService(ITimePunchRepository repo)
    {
        _repo = repo;
    }

    public async Task<EmployeeStatusDto> GetStatusAsync(string employeeId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(employeeId)) 
            return new EmployeeStatusDto { IsClockedIn = false };

        if (!Guid.TryParse(employeeId, out var empGuid))
            return new EmployeeStatusDto { IsClockedIn = false };

        var last = await _repo.GetLastPunchTypeAsync(empGuid, ct);

        return new EmployeeStatusDto
        {
            IsClockedIn = (last == PunchType.ClockIn),
            LastPunchType = last
        };
    }
}
