namespace TimeClock.Application.DTOs;

public sealed class SyncResultDto
{
    public int Processed { get; init; }
    public IReadOnlyList<long> AcceptedLocalSequenceNumbers { get; init; } = Array.Empty<long>();
}
