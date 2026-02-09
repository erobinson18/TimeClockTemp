using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Integrations;
using TimeClock.Application.Integrations.Models;
using TimeClock.Infrastructure.Integrations.Stub;

namespace TimeClock.Infrastructure.Integrations;

public sealed class StubEmployeeDirectoryGateway : IEmployeeDirectoryGateway
{
    public Task<IReadOnlyList<EmployeeDirectoryItem>> GetAllAsync(
        CancellationToken ct = default)
    {
        var items = StubRoster.Employees
            .Select(e => new EmployeeDirectoryItem
            {
                EmployeeId = e.EmployeeId,
                EmployeeNumber = e.EmployeeNumber,
                FullName = e.FullName
            })
            .ToList();
            
        return Task.FromResult<IReadOnlyList<EmployeeDirectoryItem>>(items);
    }
}
