using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;

namespace TimeClock.Application.Services;

public class EmployeeVerificationService : IEmployeeVerificationService
{
    public Task<VerifyEmployeeResultDto> VerifyAsync(VerifyEmployeeRequestDto request)
    {
        // Temp stub till real implementation is done
        var ok = !string.IsNullOrWhiteSpace(request.EmployeeId);

        return Task.FromResult(new VerifyEmployeeResultDto
        {
            IsValid = ok,
            EmployeeId = ok ? request.EmployeeId : null,
            DisplayName = ok ? "Employee" : null
        });
    }
}
