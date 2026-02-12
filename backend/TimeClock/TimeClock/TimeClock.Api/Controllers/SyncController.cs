using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/sync")]
public sealed class SyncController : ControllerBase
{
    private readonly IPunchSyncService _sync;

    public SyncController(IPunchSyncService sync)
    {
        _sync = sync;
    }

    [HttpPost("batch")]
    public async Task<ActionResult<SyncPunchBatchResultDto>> Batch([FromBody] SyncPunchBatchDto batch, CancellationToken ct)
    {
        var result = await _sync.SyncAsync(batch);
        return Ok(result);
    }
}
