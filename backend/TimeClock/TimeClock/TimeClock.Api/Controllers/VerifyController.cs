using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/verify")]
public sealed class VerifyController : ControllerBase
{
    private readonly IEmployeeVerificationService _service;

    public VerifyController(IEmployeeVerificationService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<IActionResult> Verify([FromBody] VerifyRequestDto request, CancellationToken ct)
    {
        var empNum = request?.GetEmployeeNumber()?.Trim();

        if (string.IsNullOrWhiteSpace(empNum))
        {
            return BadRequest("employeeNumber (or employeeId) is required.");
        }

        // Service returns a result with IsValid true/false
        var result = await _service.VerifyAsync(empNum, ct);

        // IMPORTANT: never return 401 for invalid employee id
        return Ok(result);
    }
}
