using System.Text.Json.Serialization;

namespace TimeClock.Application.DTOs;

public sealed class VerifyRequestDto
{
    // preferred
    [JsonPropertyName("employeeNumber")]
    public string? EmployeeNumber { get; set; }

    // backward-compat with older Flutter code
    [JsonPropertyName("employeeId")]
    public string? EmployeeId { get; set; }

    public string? GetEmployeeNumber()
        => !string.IsNullOrWhiteSpace(EmployeeNumber) ? EmployeeNumber
         : !string.IsNullOrWhiteSpace(EmployeeId) ? EmployeeId
         : null;
}