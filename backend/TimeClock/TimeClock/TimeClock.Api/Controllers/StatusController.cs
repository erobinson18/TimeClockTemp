using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.Interfaces;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/status")]
public sealed class StatusController : ControllerBase
{
    private readonly IEmployeeStatusService _service;

    public StatusController(IEmployeeStatusService service)
    {
        _service = service;
    }

    [HttpGet("{employeeId}")]
    public async Task<IActionResult> Get(string employeeId, CancellationToken ct)
    {
        var status = await _service.GetStatusAsync(employeeId, ct);
        return Ok(status);
    }
}
