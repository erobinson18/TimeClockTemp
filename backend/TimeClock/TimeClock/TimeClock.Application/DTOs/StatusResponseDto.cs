using System.Text.Json.Serialization;

namespace TimeClock.Application.DTOs;

public sealed class StatusResponseDto
{
    [JsonPropertyName("isClockedIn")]
    public bool IsClockedIn { get; init; }

    public StatusResponseDto(bool isClockedIn)
    {
        IsClockedIn = isClockedIn;
    }
}
