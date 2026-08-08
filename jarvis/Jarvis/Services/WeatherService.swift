import CoreLocation
import Foundation

/// Tiempo actual vía Open-Meteo (API pública sin clave). Si Claude no aporta
/// coordenadas, se obtiene una posición puntual con CoreLocation.
@MainActor
final class WeatherService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentWeather(latitude: Double?, longitude: Double?) async throws -> String {
        let coordinate: CLLocationCoordinate2D
        if let latitude, let longitude {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            coordinate = try await requestLocation()
        }
        return try await fetchWeather(at: coordinate)
    }

    // MARK: - Ubicación puntual

    private func requestLocation() async throws -> CLLocationCoordinate2D {
        guard locationContinuation == nil else {
            throw ToolError("Ya hay una petición de ubicación en curso.")
        }

        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            throw ToolError("El usuario no ha concedido acceso a la ubicación.")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            if locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.requestLocation()
            }
            // Si el permiso está pendiente, locationManagerDidChangeAuthorization
            // disparará requestLocation() al concederse.
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard locationContinuation != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                locationContinuation?.resume(
                    throwing: ToolError("El usuario no ha concedido acceso a la ubicación.")
                )
                locationContinuation = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let coordinate = locations.first?.coordinate else { return }
            locationContinuation?.resume(returning: coordinate)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: ToolError("No se pudo obtener la ubicación."))
            locationContinuation = nil
        }
    }

    // MARK: - Open-Meteo

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature2M: Double
            let apparentTemperature: Double
            let weatherCode: Int
            let windSpeed10M: Double

            private enum CodingKeys: String, CodingKey {
                case temperature2M = "temperature_2m"
                case apparentTemperature = "apparent_temperature"
                case weatherCode = "weather_code"
                case windSpeed10M = "wind_speed_10m"
            }
        }

        let current: Current
    }

    private func fetchWeather(at coordinate: CLLocationCoordinate2D) async throws -> String {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m"),
        ]

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: components.url!)
        } catch {
            throw ToolError("No se pudo consultar el servicio meteorológico.")
        }

        guard let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
            throw ToolError("Respuesta meteorológica inesperada.")
        }

        let current = decoded.current
        let description = Self.description(forWMOCode: current.weatherCode)
        return "Ahora mismo: \(description), \(Int(current.temperature2M.rounded())) grados "
            + "(sensación de \(Int(current.apparentTemperature.rounded()))), "
            + "viento de \(Int(current.windSpeed10M.rounded())) kilómetros por hora."
    }

    /// Traducción de los códigos WMO de Open-Meteo.
    static func description(forWMOCode code: Int) -> String {
        switch code {
        case 0: return "cielo despejado"
        case 1: return "mayormente despejado"
        case 2: return "parcialmente nublado"
        case 3: return "nublado"
        case 45, 48: return "niebla"
        case 51, 53, 55: return "llovizna"
        case 56, 57: return "llovizna helada"
        case 61, 63, 65: return "lluvia"
        case 66, 67: return "lluvia helada"
        case 71, 73, 75: return "nieve"
        case 77: return "cinarra"
        case 80, 81, 82: return "chubascos"
        case 85, 86: return "chubascos de nieve"
        case 95: return "tormenta"
        case 96, 99: return "tormenta con granizo"
        default: return "condiciones variables"
        }
    }
}
