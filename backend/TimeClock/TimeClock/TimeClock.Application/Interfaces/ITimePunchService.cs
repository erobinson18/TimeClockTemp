using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TimeClock.Application.Commands;

namespace TimeClock.Application.Interfaces;

public interface ITimePunchService
{
    Task CreateAsync(CreateTimePunchCommand command);
}
