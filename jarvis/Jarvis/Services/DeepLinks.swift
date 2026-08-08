import CoreLocation
import Foundation
import UIKit

/// Acciones que se completan en otra app vía enlaces universales:
/// Jarvis prepara todo y el usuario da el último toque (enviar/confirmar).
@MainActor
enum DeepLinks {
    // MARK: - WhatsApp

    /// Abre WhatsApp con el chat y el mensaje ya escritos (wa.me es un enlace
    /// universal: si la app no está instalada, se abre WhatsApp Web).
    static func openWhatsApp(number: String, recipientName: String, message: String) async throws -> String {
        var components = URLComponents(string: "https://wa.me/\(number)")!
        components.queryItems = [URLQueryItem(name: "text", value: message)]
        guard let url = components.url else {
            throw ToolError("No he podido construir el enlace de WhatsApp.")
        }
        let opened = await UIApplication.shared.open(url)
        guard opened else {
            throw ToolError("No se pudo abrir WhatsApp.")
        }
        return "Le he preparado el mensaje para \(recipientName) — solo falta pulsar enviar."
    }

    // MARK: - Uber

    /// Geocodifica el destino y abre Uber con la recogida en la ubicación
    /// actual y el destino fijado; el usuario confirma el viaje en la app.
    static func requestUber(destination: String) async throws -> String {
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await CLGeocoder().geocodeAddressString(destination)
        } catch {
            throw ToolError("No he podido localizar «\(destination)».")
        }
        guard let location = placemarks.first?.location else {
            throw ToolError("No he podido localizar «\(destination)».")
        }

        let nickname = placemarks.first?.name ?? destination
        var components = URLComponents(string: "https://m.uber.com/ul/")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "setPickup"),
            URLQueryItem(name: "pickup", value: "my_location"),
            URLQueryItem(name: "dropoff[latitude]", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "dropoff[longitude]", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "dropoff[nickname]", value: nickname),
        ]
        guard let url = components.url else {
            throw ToolError("No he podido construir el enlace de Uber.")
        }
        let opened = await UIApplication.shared.open(url)
        guard opened else {
            throw ToolError("No se pudo abrir Uber.")
        }
        return "He preparado el viaje a \(nickname) — confirme el pedido en Uber."
    }
}
