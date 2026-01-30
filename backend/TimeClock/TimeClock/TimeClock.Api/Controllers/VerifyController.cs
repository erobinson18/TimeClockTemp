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
    public async Task<IActionResult> Verify([FromBody] VerifyEmployeeRequestDto request)
    {
        var result = await _service.VerifyAsync(request);
        return Ok(result);
    }
}