using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Enums;

namespace TimeClock.Application.DTOs;

public class SyncPunchBatchDto
{
    public string DeviceId { get; set; } = string.Empty;
    public DeviceType DeviceType { get; set; }
    public List<SyncPunchDto> Punches { get; set; } = new();
}

public class SyncPunchDto
{
    public Guid EmployeeId { get; set; }
    public PunchType PunchType { get; set; }
    public long LocalSequenceNumber { get; set; }
    public DateTime TimestampUtc { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}
