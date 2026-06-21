// Services/WeatherService.swift
// Fetches current weather + today's high/low from the free Open-Meteo API
// (no API key required) using the device's current location.

import Foundation

class WeatherService {

  // Returns a spoken-friendly summary like:
  // "Right now it's 72 degrees and partly cloudy, feels like 70. Today's high is 78, low 60."
  static func currentSummary() async -> String {
    guard let location = LocationService.shared.currentLocation else {
      return "I can't get your location for the weather right now."
    }

    let lat = location.coordinate.latitude
    let lon = location.coordinate.longitude
    let urlString = "https://api.open-meteo.com/v1/forecast"
      + "?latitude=\(lat)&longitude=\(lon)"
      + "&current=temperature_2m,apparent_temperature,weather_code"
      + "&daily=temperature_2m_max,temperature_2m_min"
      + "&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&forecast_days=1"

    guard let url = URL(string: urlString) else { return "Weather is unavailable right now." }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let current = json["current"] as? [String: Any] else {
        return "Weather is unavailable right now."
      }

      let temp = roundedString(current["temperature_2m"])
      let feels = roundedString(current["apparent_temperature"])
      let code = (current["weather_code"] as? NSNumber)?.intValue ?? -1
      let condition = describe(weatherCode: code)

      var summary = "Right now it's \(temp) degrees and \(condition)"
      if !feels.isEmpty, feels != temp {
        summary += ", feels like \(feels)"
      }
      summary += "."

      if let daily = json["daily"] as? [String: Any],
         let highs = daily["temperature_2m_max"] as? [Any], let high = highs.first,
         let lows = daily["temperature_2m_min"] as? [Any], let low = lows.first {
        summary += " Today's high is \(roundedString(high)), low \(roundedString(low))."
      }
      return summary
    } catch {
      return "Weather is unavailable right now."
    }
  }

  private static func roundedString(_ value: Any?) -> String {
    guard let n = value as? NSNumber else { return "" }
    return String(Int(n.doubleValue.rounded()))
  }

  // Maps WMO weather codes to plain-language descriptions.
  private static func describe(weatherCode code: Int) -> String {
    switch code {
    case 0: return "clear"
    case 1: return "mostly clear"
    case 2: return "partly cloudy"
    case 3: return "overcast"
    case 45, 48: return "foggy"
    case 51, 53, 55: return "drizzly"
    case 56, 57: return "freezing drizzle"
    case 61, 63, 65: return "rainy"
    case 66, 67: return "freezing rain"
    case 71, 73, 75, 77: return "snowy"
    case 80, 81, 82: return "rain showers"
    case 85, 86: return "snow showers"
    case 95: return "thunderstorms"
    case 96, 99: return "thunderstorms with hail"
    default: return "unsettled"
    }
  }
}
