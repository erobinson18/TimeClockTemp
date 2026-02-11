using System.Threading;
using System.Threading.Tasks;
using TimeClock.Application.Commands;
using TimeClock.Application.Interfaces;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Enums;
using TimeClock.Domain.Interfaces;

namespace TimeClock.Application.Services;

public sealed class TimePunchService : ITimePunchService
{
    private readonly ITimePunchRepository _repository;

    public TimePunchService(ITimePunchRepository repository)
    {
        _repository = repository;
    }

    public async Task CreateAsync(CreateTimePunchCommand command)
    {
        var punch = new TimePunch(
            command.EmployeeId,
            command.PunchType,
            command.DeviceType,
            command.DeviceId,
            command.LocalSequenceNumber,
            command.Location,
            command.TimestampUtc
        );

        await _repository.AddAsync(punch);
    }

    public async Task<bool> IsEmployeeClockedInAsync(string employeeId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(employeeId))
            return false;

        if (!Guid.TryParse(employeeId, out var guid))
            return false;

        var lastPunchType = await _repository.GetLastPunchTypeAsync(guid, ct);

        if (!lastPunchType.HasValue)
            return false;

        return lastPunchType.Value == (int)PunchType.ClockIn
               || lastPunchType.Value == 1;
    }
}
