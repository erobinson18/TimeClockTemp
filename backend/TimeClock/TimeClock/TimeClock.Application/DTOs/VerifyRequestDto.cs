using System.Text.Json.Serialization;

namespace TimeClock.Application.DTOs;

// Controller input DTO (what Flutter sends)
public sealed class VerifyRequestDto
{
    // preferred
    [JsonPropertyName("employeeNumber")]
    public string? EmployeeNumber { get; set; }

    // backward-compat with existing Flutter code
    [JsonPropertyName("employeeId")]
    public string? EmployeeId { get; set; }

    public string? GetEmployeeNumber()
        => !string.IsNullOrWhiteSpace(EmployeeNumber) ? EmployeeNumber
         : !string.IsNullOrWhiteSpace(EmployeeId) ? EmployeeId
         : null;
}
