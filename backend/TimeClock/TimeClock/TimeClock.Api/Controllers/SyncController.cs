using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.Interfaces;
using TimeClock.Application.DTOs;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SyncController : ControllerBase
{
    private readonly IPunchSyncService _service;

    public SyncController(IPunchSyncService service)
    {
        _service = service;
    }

    [HttpPost("batch")]
    public async Task<IActionResult> Batch([FromBody] SyncPunchBatchDto batch)
    {
        var processed = await _service.SyncAsync(batch);

        return Ok(new { Success = true, processed });
    }
}
