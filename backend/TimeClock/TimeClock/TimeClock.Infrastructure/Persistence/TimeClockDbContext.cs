using Microsoft.EntityFrameworkCore;
using TimeClock.Domain.Entities;
using TimeClock.Domain.ValueObjects;

namespace TimeClock.Infrastructure;

public sealed class TimeClockDbContext : DbContext
{
    public TimeClockDbContext(DbContextOptions<TimeClockDbContext> options)
        : base(options) { }

    public DbSet<TimePunch> TimePunches => Set<TimePunch>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<TimePunch>(b =>
        {
            b.ToTable("TimePunches");

            b.HasKey(x => x.Id);

            b.HasIndex(x => new { x.EmployeeId, x.DeviceId, x.LocalSequenceNumber })
             .IsUnique();

            b.OwnsOne(x => x.Location, owned =>
            {
                owned.Property(p => p.Latitude).HasColumnName("Latitude");
                owned.Property(p => p.Longitude).HasColumnName("Longitude");
            });

            // Optional: if Location can be null
            b.Navigation(x => x.Location).IsRequired(false);
        });
    }
}
