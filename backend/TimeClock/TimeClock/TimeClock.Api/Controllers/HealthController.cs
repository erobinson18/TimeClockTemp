using Microsoft.AspNetCore.Mvc;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/health")]
public class HealthController : ControllerBase
{
    [HttpGet("ping")]
    public IActionResult Ping() => Ok();
}
