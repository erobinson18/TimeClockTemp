using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Enums;
using TimeClock.Domain.ValueObjects;

namespace TimeClock.Application.Commands;

public record CreateTimePunchCommand
    (
    Guid EmployeeId,
    PunchType PunchType,
    DeviceType DeviceType,
    string DeviceId,
    long LocalSequenceNumber,
    GeoCoordinate? Location,
    DateTime TimestampUtc
);

internal class CreatePunchCommand
{
}
