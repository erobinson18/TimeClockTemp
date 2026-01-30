using TimeClock.Application.Interfaces;
using TimeClock.Application.Services;
using TimeClock.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddScoped<IEmployeeVerificationService, EmployeeVerificationService>();
builder.Services.AddScoped<IEmployeeStatusService, EmployeeStatusService>();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var conn = builder.Configuration.GetConnectionString("TimeClockDb")!;
builder.Services.AddInfrastructure(conn);

// Application
builder.Services.AddScoped<ITimePunchService, TimePunchService>();


var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
