using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.Interfaces;
using TimeClock.Application.DTOs;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class SyncController : ControllerBase
{
    private readonly IPunchSyncService _syncService;

    public SyncController(IPunchSyncService syncService)
    {
        _syncService = syncService;
    }

    [HttpPost("batch")]
    public async Task<IActionResult> Batch([FromBody] SyncPunchBatchDto batch)
    {
        // Process
        var processed = await _syncService.SyncAsync(batch);

        // We accept all sequence numbers we received (simple + reliable for offline queue cleanup)
        var acceptedSeq = batch.Punches
            .Select(p => (int)p.LocalSequenceNumber)
            .ToList();

        return Ok(new
        {
            processed,
            acceptedSeq
        });
    }
}
