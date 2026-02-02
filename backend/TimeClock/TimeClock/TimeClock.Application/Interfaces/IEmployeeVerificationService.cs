using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.DTOs;
using TimeClock.Application.Services;

namespace TimeClock.Application.Interfaces;

public interface IEmployeeVerificationService
{
    Task<VerifyEmployeeResultDto> VerifyAsync(VerifyEmployeeRequestDto request);
}
