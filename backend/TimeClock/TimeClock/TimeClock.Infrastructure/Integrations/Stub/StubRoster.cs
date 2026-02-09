using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Integrations.Models;

namespace TimeClock.Infrastructure.Integrations.Stub;

public static class StubRoster
{
    public sealed class  StubEmployee
    {
        public Guid EmployeeId { get; init; }
        public string EmployeeNumber { get; init; } = string.Empty; // 5–6 digits as string
        public string FullName { get; init; } = string.Empty;       // "LAST, FIRST MIDDLE"
    }

    public static readonly List<StubEmployee> Employees = new()
    {
        new StubEmployee
        {
            EmployeeId = Guid.Parse("3fa85f64-5717-4562-b3fc-2c963f66afa6"),
            EmployeeNumber = "12345",
            FullName = "DOE, JOHN A."
        },

        new StubEmployee
        {
            EmployeeId = Guid.Parse("11111111-1111-1111-1111-111111111111"),
            EmployeeNumber = "67890",
            FullName = "SMITH, JANE B."
        }
    };
}
