using System;
using System.Threading;
using System.Threading.Tasks;
using TimeClock.Application.DTOs;
using TimeClock.Application.Interfaces;
using TimeClock.Application.Integrations;

namespace TimeClock.Application.Services;

public sealed class EmployeeVerificationService : IEmployeeVerificationService
{
    private readonly IEmployeeVerificationGateway _gateway;

    public EmployeeVerificationService(IEmployeeVerificationGateway gateway)
    {
        _gateway = gateway;
    }

    public async Task<VerifyEmployeeResultDto> VerifyAsync(string employeeNumber, CancellationToken ct)
    {
        var verified = await _gateway.VerifyByEmployeeNumberAsync(employeeNumber, ct);

        if (verified == null)
        {
            return new VerifyEmployeeResultDto
            {
                IsValid = false
            };
        }

        return new VerifyEmployeeResultDto
        {
            IsValid = true,
            EmployeeId = verified.EmployeeId.ToString(),
            FullName = verified.FullName,
            IsClockedIn = verified.IsClockedIn
        };
    }
}
