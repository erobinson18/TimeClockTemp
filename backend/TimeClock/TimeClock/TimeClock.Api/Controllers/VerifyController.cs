using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.Interfaces;
using TimeClock.Application.DTOs;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/verify")]
public class VerifyController : ControllerBase
{
    private readonly IEmployeeVerificationService _service;
    public VerifyController(IEmployeeVerificationService service)
    {
        _service = service;
    }

[HttpPost]
public async Task<IActionResult> Verify([FromBody] VerifyRequest request, CancellationToken ct)
{
    var result = await _verification.VerifyByEmployeeNumberAsync(
        request.EmployeeNumber, ct);

    if (result == null)
        return Unauthorized();

    return Ok(result);
}

}