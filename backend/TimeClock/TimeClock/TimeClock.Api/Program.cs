using Microsoft.AspNetCore.Mvc.ModelBinding.Binders;
using TimeClock.Application.Interfaces;
using TimeClock.Application.Services;
using TimeClock.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddScoped<IEmployeeVerificationService, EmployeeVerificationService>();
builder.Services.AddScoped<IEmployeeStatusService, EmployeeStatusService>();
builder.Services.AddScoped<ITimePunchService, TimePunchService>();
builder.Services.AddScoped<IPunchSyncService, PunchSyncService>();
builder.Services.AddCors(options =>
{
    options.AddPolicy("DevCors", policy =>
    {
        policy
        .WithOrigins(
            "http://localhost:53585", // Flutter web dev server
            "http://localhost:5160"
        )
        .AllowAnyMethod()
        .AllowAnyHeader();
    });
});

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var conn = builder.Configuration.GetConnectionString("TimeClockDb")!;
builder.Services.AddInfrastructure(conn);

// Application
builder.Services.AddScoped<ITimePunchService, TimePunchService>();


var app = builder.Build();
app.UseCors("DevCors");

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("DevCors");

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
