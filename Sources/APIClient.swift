import Foundation

// MARK: - Solmove API client
// Networking layer that talks to the solmove-api backend.
// Point `baseURL` at your running API (see ../solmove-api).
//
// This is an additive layer: the app currently runs on the local `Store`
// with seeded data. To go live, swap `Store`'s data sources for calls to
// `SolmoveAPI.shared` (login, fetchStudios, book, etc.).

actor SolmoveAPI {
    static let shared = SolmoveAPI()

    /// Override with your deployed URL. Use your machine's LAN IP (not
    /// localhost) when testing on a physical device.
    var baseURL = URL(string: "http://localhost:4000/api/v1")!

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "solmove.jwt") }
    }
    private func setToken(_ t: String?) {
        if let t { UserDefaults.standard.set(t, forKey: "solmove.jwt") }
        else { UserDefaults.standard.removeObject(forKey: "solmove.jwt") }
    }

    enum APIError: Error, LocalizedError {
        case http(Int, String)
        case decoding(String)
        var errorDescription: String? {
            switch self {
            case .http(let code, let msg): return "HTTP \(code): \(msg)"
            case .decoding(let msg): return "Decoding error: \(msg)"
            }
        }
    }

    // MARK: Core request

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authorized: Bool = false
    ) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(-1, "No response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: Auth / enrollment

    struct AuthResponse: Decodable { let token: String; let user: APIUser }

    func register(email: String, password: String, name: String, role: String) async throws -> APIUser {
        let res: AuthResponse = try await request(
            "auth/register", method: "POST",
            body: ["email": email, "password": password, "name": name, "role": role])
        setToken(res.token)
        return res.user
    }

    func login(email: String, password: String) async throws -> APIUser {
        let res: AuthResponse = try await request(
            "auth/login", method: "POST",
            body: ["email": email, "password": password])
        setToken(res.token)
        return res.user
    }

    func logout() { setToken(nil) }

    // MARK: Reads

    func fetchStudios() async throws -> [APIStudio] {
        try await request("studios")
    }
    func fetchInstructors() async throws -> [APIInstructor] {
        try await request("instructors")
    }
    func fetchTiers() async throws -> [APITier] {
        try await request("memberships/tiers")
    }
    func fetchClasses() async throws -> [APIClass] {
        try await request("classes")
    }
    func me() async throws -> APIMe {
        try await request("auth/me", authorized: true)
    }
    func fetchThreads() async throws -> [APIThread] {
        try await request("messages/threads", authorized: true)
    }
    func fetchThread(id: String) async throws -> APIThread {
        try await request("messages/threads/\(id)", authorized: true)
    }

    // MARK: Actions

    func enrollMembership(tierSlug: String) async throws {
        let _: EmptyResponse = try await request(
            "memberships/enroll", method: "POST",
            body: ["tierSlug": tierSlug], authorized: true)
    }
    func book(classId: String) async throws {
        let _: EmptyResponse = try await request(
            "bookings", method: "POST", body: ["classId": classId], authorized: true)
    }
    func claimShift(id: String) async throws {
        let _: EmptyResponse = try await request(
            "shifts/\(id)/claim", method: "POST", authorized: true)
    }
    func rate(targetType: String, targetId: String, stars: Int) async throws {
        let _: EmptyResponse = try await request(
            "ratings", method: "POST",
            body: RateBody(targetType: targetType, targetId: targetId, stars: stars),
            authorized: true)
    }
    func sendMessage(studioId: String?, instructorId: String?, text: String) async throws {
        let _: EmptyResponse = try await request(
            "messages/send", method: "POST",
            body: SendBody(studioId: studioId, instructorId: instructorId, text: text),
            authorized: true)
    }
}

// MARK: - DTOs (match the API JSON)

struct APIUser: Decodable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: String
    let avatarUrl: String?
    let city: String?
}

struct APIStudio: Decodable, Identifiable {
    let id: String
    let name: String
    let neighborhood: String
    let lat: Double?
    let lon: Double?
    let foundingPartner: Bool
    let rating: Double
    let ratingCount: Int
    let followers: Int
}

struct APIInstructor: Decodable, Identifiable {
    let id: String
    let name: String
    let disciplines: [String]
    let xp: Int
    let level: Int
    let title: String
    let shiftsCovered: Int?
    let rating: Double
    let followers: Int
}

struct APITier: Decodable, Identifiable {
    let id: String
    let slug: String
    let name: String
    let priceMonthly: Int
    let creditsPerMonth: Int
}

struct APIClass: Decodable, Identifiable {
    let id: String
    let studioId: String
    let instructorId: String?
    let title: String
    let discipline: String
    let dayOfWeek: Int
    let time: String
    let capacity: Int
    let creditCost: Int
    let booked: Int?
    let spotsLeft: Int?
}

// /auth/me — resolves which studio/instructor the user represents.
struct APIMe: Decodable {
    let id: String
    let name: String
    let role: String
    let instructor: APIMeInstructor?
    let studioAdminOf: [APIMeStudioAdmin]?
}
struct APIMeInstructor: Decodable { let id: String }
struct APIMeStudioAdmin: Decodable { let studio: APIStudioRef }
struct APIStudioRef: Decodable { let id: String; let name: String }

struct APIThread: Decodable, Identifiable {
    let id: String
    let studioId: String
    let instructorId: String
    let studio: APIStudioRef?
    let messages: [APIMessage]?
}
struct APIMessage: Decodable, Identifiable {
    let id: String
    let senderRole: String
    let text: String
    let createdAt: String
}

// MARK: - Encoding helpers

struct EmptyResponse: Decodable {}
private struct RateBody: Encodable { let targetType: String; let targetId: String; let stars: Int }
private struct SendBody: Encodable { let studioId: String?; let instructorId: String?; let text: String }

/// Type-erased Encodable so we can send `[String: String]` or structs uniformly.
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
