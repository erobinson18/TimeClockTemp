using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Domain.ValueObjects;

public sealed class GeoCoordinate
{
    public double Latitude { get; private set; }
    public double Longitude { get; private set; }

    private GeoCoordinate() { } // EF

    public GeoCoordinate(double latitude, double longitude)
    {
        Latitude = latitude;
        Longitude = longitude;
    }
}
