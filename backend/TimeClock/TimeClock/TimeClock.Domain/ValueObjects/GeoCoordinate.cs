using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TimeClock.Domain.ValueObjects;

public class GeoCoordinate
{
    public double Latitude { get; private set; }
    public double Longitude { get; private set; }

    //EF needs a  parameterless constructor
    private GeoCoordinate() { }

    public GeoCoordinate(double latitude, double longitude)
    {
        Latitude = latitude;
        Longitude = longitude;
    }
}