using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using TimeClock.Domain.Entities;

namespace TimeClock.Infrastructure.Persistence;

public class TimeClockDbContext : DbContext
{
    public TimeClockDbContext(DbContextOptions<TimeClockDbContext> options) : base(options) { }

    public DbSet<TimePunch> TimePunches { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<TimePunch>(entity =>
        {
            entity.OwnsOne(p => p.Location, owned =>
            {
                owned.Property(x => x.Latitude)
                     .HasColumnName("Latitude");

                owned.Property(x => x.Longitude)
                     .HasColumnName("Longitude");
            });

            entity.Navigation(p => p.Location)
                  .IsRequired(false);
        });
    }
}
