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
        if (request == null)
            return BadRequest("Request body is required.");

        var empNum = request.GetEmployeeNumber();

        if (string.IsNullOrWhiteSpace(empNum))
            return BadRequest("EmployeeNumber (or EmployeeId) is required.");

        var appRequest = new VerifyEmployeeRequestDto
        {
            EmployeeNumber = empNum.Trim()
        };

        var result = await _service.VerifyAsync(appRequest);

        if (result == null)
            return Unauthorized();

        return Ok(result);
    }
}
