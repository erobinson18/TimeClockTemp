using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.DTOs;

namespace TimeClock.Application.Interfaces;

public interface IPunchSyncService
{
    Task<int> SyncAsync(SyncPunchBatchDto batch);
}
