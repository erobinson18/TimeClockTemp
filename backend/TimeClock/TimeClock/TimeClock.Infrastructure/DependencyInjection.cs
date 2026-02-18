using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using TimeClock.Domain.Interfaces;
using TimeClock.Application.Integrations;
using TimeClock.Infrastructure.Integrations;
using TimeClock.Application.Services;
using TimeClock.Application.Interfaces;
using TimeClock.Infrastructure.Persistence.Repositories;

namespace TimeClock.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        string? connectionString)
    {
        services.AddDbContext<TimeClockDbContext>(opt =>
            opt.UseSqlServer(connectionString));

        services.AddScoped<ITimePunchRepository, TimePunchRepository>();

        services.AddScoped<ITimePunchService, TimePunchService>();
        services.AddScoped<IEmployeeStatusService, EmployeeStatusService>();

        services.AddScoped<IEmployeeVerificationService, EmployeeVerificationService>();

        services.AddScoped<IEmployeeDirectoryGateway, StubEmployeeDirectoryGateway>();
        services.AddScoped<IEmployeeVerificationGateway, StubEmployeeVerificationGateway>();
        services.AddScoped<IEmployeeStatusGateway, EfEmployeeStatusGateway>();
        services.AddScoped<IPunchWriterGateway, StubPunchWriterGateway>();

        return services;
    }
}
