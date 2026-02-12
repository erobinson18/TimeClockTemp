using TimeClock.Application.DTOs;

namespace TimeClock.Application.Interfaces;

public interface IPunchSyncService
{
    Task<SyncPunchBatchResultDto> SyncAsync(SyncPunchBatchDto batch);
}
