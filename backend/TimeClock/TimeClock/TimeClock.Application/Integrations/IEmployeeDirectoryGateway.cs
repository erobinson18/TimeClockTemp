using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Integrations.Models;


namespace TimeClock.Application.Integrations;

public interface IEmployeeDirectoryGateway 
{
    Task<IReadOnlyList<EmployeeDirectoryItem>> GetAllAsync(
        CancellationToken ct = default
    );
}
