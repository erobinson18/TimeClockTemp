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

    public DbSet<TimePunch> TimePunches => Set<TimePunch>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<TimePunch>(entity =>
        {
            entity.ToTable("TimePunches");
            entity.HasKey(x => x.Id);

            entity.Property(x => x.EmployeeId).IsRequired();
            entity.Property(x => x.PunchType).IsRequired();
            entity.Property(x => x.DeviceType).IsRequired();
            entity.Property(x => x.DeviceId).IsRequired();
            entity.Property(x => x.LocalSequenceNumber).IsRequired();
            entity.Property(x => x.TimestampUtc).IsRequired();

            // Map GeoCoordinate? as owned type (nullable)
            entity.OwnsOne(x => x.Location, owned =>
            {
                owned.Property(p => p.Latitude).HasColumnName("Latitude");
                owned.Property(p => p.Longitude).HasColumnName("Longitude");
            });
        });
    }
}
