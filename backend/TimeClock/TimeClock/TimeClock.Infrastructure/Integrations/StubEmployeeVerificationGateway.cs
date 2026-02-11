using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Integrations;
using TimeClock.Application.Integrations.Models;
using TimeClock.Infrastructure.Integrations.Stub;

namespace TimeClock.Infrastructure.Integrations;

public sealed class StubEmployeeVerificationGateway : IEmployeeVerificationGateway
{
    public Task<VerifiedEmployee?> VerifyByEmployeeNumberAsync(
        string employeeNumber,
        CancellationToken ct = default)
    {
        var emp = StubRoster.Employees
            .FirstOrDefault(e => e.EmployeeNumber == employeeNumber);

        if (emp == null)
            return Task.FromResult<VerifiedEmployee?>(null);

        return Task.FromResult<VerifiedEmployee?>(new VerifiedEmployee
        {
            EmployeeId = emp.EmployeeId.ToString(),
            EmployeeNumber = emp.EmployeeNumber,
            FullName = emp.FullName,
            IsClockedIn = emp.IsClockedIn
        });
    }
}
