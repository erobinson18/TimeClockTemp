using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Domain.Entities;

public sealed class Employee
{
    public Guid Id { get; private set; }
    public string EmployeeNumber { get; private set; } = string.Empty; // 5–6 digits as string
    public string FirstName { get; private set; } = string.Empty;
    public string? MiddleName { get; private set; }
    public string LastName { get; private set; } = string.Empty;
    public bool IsActive { get; private set; } = true;

    private Employee() { } // For EF Core

    public Employee(string employeeNumber, string firstName, string lastName, string? middleName = null)
    {
        if (string.IsNullOrWhiteSpace(employeeNumber)) throw new ArgumentException("EmployeeNumber is required.");
        if (string.IsNullOrWhiteSpace(firstName)) throw new ArgumentException("FirstName is required.");
        if (string.IsNullOrWhiteSpace(lastName)) throw new ArgumentException("LastName is required.");

        Id = Guid.NewGuid();
        EmployeeNumber = employeeNumber.Trim();
        FirstName = firstName.Trim();
        MiddleName = string.IsNullOrWhiteSpace(middleName) ? null : middleName.Trim();
        LastName = lastName.Trim();
        IsActive = true;
    }

    public string FullName => $"{LastName.ToUpperInvariant()}, {FirstName}{(string.IsNullOrWhiteSpace(MiddleName) ? "" : $" {MiddleName}")}";

    public void Deacivate() => IsActive = false;
    public void Activate() => IsActive = true;
}
