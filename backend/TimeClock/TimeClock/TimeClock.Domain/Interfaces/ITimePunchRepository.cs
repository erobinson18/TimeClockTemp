using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Domain.Entities;

namespace TimeClock.Domain.Interfaces;

public interface ITimePunchRepository
{
    Task AddAsync(TimePunch punch);
}
