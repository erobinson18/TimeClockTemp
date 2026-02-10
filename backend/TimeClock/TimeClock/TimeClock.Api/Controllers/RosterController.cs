using Microsoft.AspNetCore.Mvc;
using System.Reflection.Metadata.Ecma335;
using TimeClock.Application.Integrations;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class RosterController : ControllerBase
{
    private readonly IEmployeeDirectoryGateway _directory;

    public RosterController(IEmployeeDirectoryGateway directory)
    {
        _directory = directory;
    }

    /// <summary>
    /// Returns a list of active employees. This is used to populate the employee selection dropdown on the frontend.
    /// </summary>

    [HttpGet("all")]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var employees = await _directory.GetAllAsync(ct);
        return Ok(employees);
    }
}
