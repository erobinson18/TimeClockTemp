using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Commands;
using TimeClock.Application.Interfaces;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Interfaces;

namespace TimeClock.Application.Services;

public class TimePunchService : ITimePunchService
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
            command.Location
        );

        await _repository.AddAsync(punch);
    }
}
