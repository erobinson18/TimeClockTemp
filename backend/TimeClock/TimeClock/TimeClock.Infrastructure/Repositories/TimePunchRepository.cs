using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Entities;
using TimeClock.Domain.Interfaces;
using TimeClock.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace TimeClock.Infrastructure.Repositories;

public class TimePunchRepository : ITimePunchRepository
{
    private readonly TimeClockDbContext _db;
    public TimePunchRepository(TimeClockDbContext db)
    {
        _db = db;
    }
    public async Task AddAsync(TimePunch punch)
    {
        _db.TimePunches.Add(punch);
        await _db.SaveChangesAsync();
    }
}
