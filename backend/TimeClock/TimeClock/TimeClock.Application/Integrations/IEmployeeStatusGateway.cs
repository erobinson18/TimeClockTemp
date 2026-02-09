using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Integrations.Models;

namespace TimeClock.Application.Integrations;

public interface IEmployeeStatusGateway
{
    Task<EmployeePunchStatus> GetStatusAsync(Guid employeeId, CancellationToken ct = default);
}
