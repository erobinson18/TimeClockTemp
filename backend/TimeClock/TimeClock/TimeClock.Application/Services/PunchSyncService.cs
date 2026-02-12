using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;
using TimeClock.Application.Commands;
using TimeClock.Domain.ValueObjects;

namespace TimeClock.Application.Services;

public class PunchSyncService : IPunchSyncService
{
    private readonly ITimePunchService _PunchService;

    public PunchSyncService(ITimePunchService punchService)
    {
        _PunchService = punchService;
    }

    public async Task<SyncPunchBatchResultDto> SyncAsync(SyncPunchBatchDto batch)
    {
        var ordered = batch.Punches
            .OrderBy(p => p.TimestampUtc)
            .ThenBy(p => p.LocalSequenceNumber)
            .ToList();

        var accepted = new List<long>(ordered.Count);

        foreach (var p in ordered)
        {
            GeoCoordinate? loc =
                (p.Latitude.HasValue && p.Longitude.HasValue)
                    ? new GeoCoordinate(p.Latitude.Value, p.Longitude.Value)
                    : null;

            var cmd = new CreateTimePunchCommand(
                p.EmployeeId,
                p.PunchType,
                batch.DeviceType,
                batch.DeviceId,
                p.LocalSequenceNumber,
                loc,
                p.TimestampUtc
            );

            await _PunchService.CreateAsync(cmd);

            accepted.Add(p.LocalSequenceNumber);
        }

        return new SyncPunchBatchResultDto
        {
            Processed = accepted.Count,
            AcceptedSeq = accepted
        };
    }
}
