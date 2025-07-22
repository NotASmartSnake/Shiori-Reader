// ServerManager.swift
import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumShared
// import Combine // Combine is no longer needed here if statePublisher is removed

/**
 Manages the shared GCDHTTPServer instance required by Readium navigators.
 Ensures the server is started only once.
 */
class ServerManager {

    /// The singleton instance of the server manager.
    static let shared = ServerManager()

    /// The shared HTTP server instance.
    let httpServer: GCDHTTPServer

    // Remove the cancellable property as statePublisher doesn't exist
    // private var serverStateCancellable: AnyCancellable?

    /// Private initializer to enforce singleton pattern and start the server.
    private init() {
        print("DEBUG [ServerManager]: Initializing...")

        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)

        let server = GCDHTTPServer(
            assetRetriever: assetRetriever,
            logLevel: 3
        )
        self.httpServer = server
    }

    deinit {
        print("DEBUG [ServerManager]: Deinitializing. Stopping server.")
    }
}
