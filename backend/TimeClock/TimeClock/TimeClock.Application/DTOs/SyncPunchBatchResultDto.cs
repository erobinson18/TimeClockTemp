namespace TimeClock.Application.DTOs;

public sealed class SyncPunchBatchResultDto
{
    public int Processed { get; set; }
    public List<long> AcceptedSeq {get; set; } = new();
}