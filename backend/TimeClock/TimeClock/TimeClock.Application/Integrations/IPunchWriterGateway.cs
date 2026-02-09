using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Entities;

namespace TimeClock.Application.Integrations;

public interface IPunchWriterGateway
{
    Task WritePunchAsync(TimePunch punch, CancellationToken ct = default);
}
