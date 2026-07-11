import Foundation
import MediaPlayer

/// Reproducción en Apple Music sin MusicKit ni developer token (funciona con
/// firma de Apple ID gratuito): se resuelven los store IDs con la iTunes
/// Search API (pública, sin clave) y reproduce la app Música del sistema vía
/// MPMusicPlayerController.
@MainActor
final class MusicService {
    enum SearchType: String {
        case song, artist, album, playlist
    }

    private var player: MPMusicPlayerController {
        MPMusicPlayerController.systemMusicPlayer
    }

    // MARK: - Reproducir

    func play(query: String, type: SearchType) async throws -> String {
        try await requestAuthorization()

        if type == .playlist {
            return try playLocalPlaylist(named: query)
        }

        let (storeIDs, description) = try await resolveStoreIDs(query: query, type: type)
        guard !storeIDs.isEmpty else {
            throw ToolError("No he encontrado «\(query)» en Apple Music.")
        }

        player.setQueue(with: storeIDs.map(String.init))
        player.play()
        return "Reproduciendo \(description)."
    }

    func control(action: String) async throws -> String {
        try await requestAuthorization()
        switch action {
        case "pause":
            player.pause()
            return "Música en pausa."
        case "resume":
            player.play()
            return "Reanudando la música."
        case "next":
            player.skipToNextItem()
            return "Siguiente canción."
        case "previous":
            player.skipToPreviousItem()
            return "Canción anterior."
        default:
            throw ToolError("No conozco esa acción de reproducción.")
        }
    }

    // MARK: - Autorización

    private func requestAuthorization() async throws {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else {
            throw ToolError("El usuario no ha concedido acceso a Apple Music.")
        }
    }

    // MARK: - Playlists locales

    private func playLocalPlaylist(named query: String) throws -> String {
        let predicate = MPMediaPropertyPredicate(
            value: query,
            forProperty: MPMediaPlaylistPropertyName,
            comparisonType: .contains
        )
        let mediaQuery = MPMediaQuery.playlists()
        mediaQuery.addFilterPredicate(predicate)

        guard let playlist = mediaQuery.collections?.first, !playlist.items.isEmpty else {
            throw ToolError("No he encontrado la playlist «\(query)» en la biblioteca.")
        }
        player.setQueue(with: playlist)
        player.play()
        let name = (playlist as? MPMediaPlaylist)?.name ?? query
        return "Reproduciendo la playlist \(name)."
    }

    // MARK: - iTunes Search API

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let trackId: Int?
            let collectionId: Int?
            let trackName: String?
            let artistName: String?
            let collectionName: String?
            let isStreamable: Bool?
            let wrapperType: String?
        }

        let results: [Item]
    }

    /// Los store IDs son por país (storefront): un ID de EE. UU. puede no
    /// reproducirse en una cuenta española, así que se busca en el storefront
    /// del dispositivo.
    private var storefront: String {
        Locale.current.region?.identifier ?? "US"
    }

    private func resolveStoreIDs(query: String, type: SearchType) async throws -> (ids: [Int], description: String) {
        switch type {
        case .song:
            let items = try await search(query: query, entity: "song", attribute: nil, limit: 5)
            guard let song = items.first(where: { $0.isStreamable == true && $0.trackId != nil })
                ?? items.first(where: { $0.trackId != nil }) else {
                return ([], "")
            }
            let description = [song.trackName, song.artistName.map { "de \($0)" }]
                .compactMap(\.self)
                .joined(separator: ", ")
            return ([song.trackId!], description)

        case .artist:
            let items = try await search(query: query, entity: "song", attribute: "artistTerm", limit: 25)
            let ids = items.filter { $0.isStreamable == true }.compactMap(\.trackId)
            let artist = items.first?.artistName ?? query
            return (ids, "música de \(artist)")

        case .album:
            let albums = try await search(query: query, entity: "album", attribute: nil, limit: 1)
            guard let collectionId = albums.first?.collectionId else { return ([], "") }
            let tracks = try await lookup(collectionId: collectionId)
            let name = albums.first?.collectionName ?? query
            let artist = albums.first?.artistName
            let description = artist.map { "el álbum \(name), de \($0)" } ?? "el álbum \(name)"
            return (tracks, description)

        case .playlist:
            return ([], "") // gestionado aparte con la biblioteca local
        }
    }

    private func search(query: String, entity: String, attribute: String?, limit: Int) async throws -> [SearchResponse.Item] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        var queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: storefront),
        ]
        if let attribute {
            queryItems.append(URLQueryItem(name: "attribute", value: attribute))
        }
        components.queryItems = queryItems
        return try await fetchResults(from: components.url!)
    }

    private func lookup(collectionId: Int) async throws -> [Int] {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(collectionId)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "country", value: storefront),
        ]
        let items = try await fetchResults(from: components.url!)
        // El primer resultado del lookup es el propio álbum; el resto, canciones.
        return items.filter { $0.wrapperType == "track" }.compactMap(\.trackId)
    }

    private func fetchResults(from url: URL) async throws -> [SearchResponse.Item] {
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw ToolError("No se pudo consultar el catálogo de Apple Music.")
        }
        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            throw ToolError("Respuesta inesperada del catálogo de música.")
        }
        return decoded.results
    }
}
