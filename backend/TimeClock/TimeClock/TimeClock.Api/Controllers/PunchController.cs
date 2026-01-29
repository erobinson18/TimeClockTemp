using Microsoft.AspNetCore.Mvc;
using TimeClock.Application.Commands;
using TimeClock.Application.Interfaces;
using TimeClock.Domain.Enums;
using TimeClock.Domain.ValueObjects;

namespace TimeClock.Api.Controllers;

[ApiController]
[Route("api/punch")]

public class PunchController : ControllerBase
{
    private readonly ITimePunchService _service;

    public PunchController(ITimePunchService service)
    {
        _service = service;
    }

    public sealed class PunchRequest
    {
        public Guid EmployeeId { get; set; }
        public PunchType PunchType { get; set; }
        public DeviceType DeviceType { get; set; }
        public string DeviceId { get; set; } = string.Empty;
        public long LocalSequenceNumber { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] PunchRequest request)
    {
        GeoCoordinate? location =
            (request.Latitude.HasValue && request.Longitude.HasValue)
                ? new GeoCoordinate(request.Latitude.Value, request.Longitude.Value)
                : null;

        var cmd = new CreateTimePunchCommand(
            request.EmployeeId,
            request.PunchType,
            request.DeviceType,
            request.DeviceId,
            request.LocalSequenceNumber,
            location
        );

        await _service.CreateAsync(cmd);
        return Ok(new { success = true });
    }
}
