using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using TimeClock.Domain.Interfaces;
using TimeClock.Infrastructure.Persistence;
using TimeClock.Infrastructure.Repositories;

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
        
        return services;
    }
}
