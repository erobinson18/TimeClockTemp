using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/status")]
public class StatusController : ControllerBase
{
    private readonly IEmployeeStatusService _service;
    public StatusController(IEmployeeStatusService service)
    {
        _service = service;
    }

    [HttpGet("{employeeId}")]
    public async Task<IActionResult> Get(string employeeId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(employeeId))
            return BadRequest("EmployeeId is required.");

        var result = await _service.GetStatusAsync(employeeId, ct);
        return Ok(result);
    }

}
