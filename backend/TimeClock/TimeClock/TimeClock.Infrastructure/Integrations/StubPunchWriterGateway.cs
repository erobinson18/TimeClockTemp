using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Integrations;
using TimeClock.Domain.Entities;

namespace TimeClock.Infrastructure.Integrations;

public sealed class StubPunchWriterGateway : IPunchWriterGateway
{
    public Task WritePunchAsync(TimePunch punch, CancellationToken ct = default)
    {
        // Placeholder. Later this will call FieldWorkCenter38 stored proc; JGG_MFMInsertPunchOTC
        return Task.CompletedTask;
    }
}
