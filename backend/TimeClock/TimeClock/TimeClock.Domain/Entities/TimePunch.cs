using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Enums;
using TimeClock.Domain.ValueObjects;


namespace TimeClock.Domain.Entities;

public class TimePunch
{
    public Guid Id { get; private set; }
    public Guid EmployeeId { get; private set; }
    public PunchType PunchType { get; private set; }
    public DeviceType DeviceType { get; private set; }
    public DateTime TimestampUtc { get; private set; }
    public string DeviceId { get; private set; }
    public long LocalSequenceNumber { get; private set; }
    public GeoCoordinate? Location { get; private set; }

    protected TimePunch() { }


    public TimePunch(
        Guid employeeId,
        PunchType punchType,
        DeviceType deviceType,
        string deviceId,
        long localSequenceNumber,
        GeoCoordinate? location = null,
        DateTime? timestampUtc = null)
    {
        if (employeeId == Guid.Empty)
            throw new ArgumentException("EmployeeId is required");

        if (string.IsNullOrWhiteSpace(deviceId))
            throw new ArgumentException("DeviceId is required");

        Id = Guid.NewGuid();
        EmployeeId = employeeId;
        PunchType = punchType;
        DeviceType = deviceType;
        DeviceId = deviceId;
        LocalSequenceNumber = localSequenceNumber;
        TimestampUtc = timestampUtc ?? DateTime.UtcNow;
        Location = location;

    }
}
