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

    [HttpGet("{employeeId:guid}")]
    public async Task<IActionResult> Get(Guid employeeId)
    {
        var result = await _service.GetStatusAsync(employeeId);

        return Ok(result);
    }

}
