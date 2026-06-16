// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession lives here on Android/Linux Foundation (same as Pricing)
#endif

/// Minimal ConnectRPC **unary** client over plain HTTP+JSON — no protobuf runtime, no gRPC. A
/// Connect unary call is just `POST <base>/<package>.<Service>/<Method>` with a JSON-encoded request
/// body and a JSON response (proto3 JSON mapping). On error Connect returns a non-2xx status with a
/// `{"code","message"}` envelope. This is all the CoinNews read API needs.
///
/// The network call is injected (`fetch`) so adapters are unit-tested with canned payloads, and the
/// seam returns `(Data, status)` rather than `URLResponse` to stay `Sendable` under Swift 6 (the
/// same shape Pricing uses).
struct ConnectRPCClient: Sendable {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, Int)

    let baseURL: URL
    let bearerToken: String?
    private let fetch: Fetch

    init(baseURL: URL, bearerToken: String? = nil, fetch: @escaping Fetch = ConnectRPCClient.defaultFetch) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
        self.fetch = fetch
    }

    static func defaultFetch(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }

    /// Call `<service>/<method>` with `request`, decode the JSON response as `Res`.
    /// `service` is the fully-qualified name, e.g. "misc.v1.MiscService".
    func unary<Req: Encodable, Res: Decodable>(service: String, method: String, request: Req) async throws -> Res {
        // Build by string: appendingPathComponent mangles the dots/slash in "pkg.Service/Method".
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        guard let url = URL(string: "\(base)/\(service)/\(method)") else { throw CoinNewsError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken { req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization") }
        do {
            req.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw CoinNewsError.decode("encode request: \(error)")
        }

        let data: Data
        let status: Int
        do {
            (data, status) = try await fetch(req)
        } catch {
            throw CoinNewsError.network
        }

        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ConnectErrorBody.self, from: data))?.message
            throw CoinNewsError.server(status: status, message: message)
        }
        do {
            return try JSONDecoder().decode(Res.self, from: data)
        } catch {
            throw CoinNewsError.decode("\(error)")
        }
    }
}

/// ConnectRPC's error envelope, returned with a non-2xx status (e.g. 401 `{"code":"unauthenticated",
/// "message":"token invalid"}`).
private struct ConnectErrorBody: Decodable {
    let code: String?
    let message: String?
}

/// Reusable empty request body → encodes to `{}` (proto `google.protobuf.Empty`).
struct EmptyRequest: Encodable {}
