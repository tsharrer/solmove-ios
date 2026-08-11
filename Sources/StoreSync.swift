import Foundation

// Online-mode integration: authenticates against solmove-api and maps the
// API's DTOs into the app's existing domain models, so every existing view
// renders live data without changes.
extension Store {
    // Local tier ids -> API membership slugs (API has starter/core/unlimited).
    static func apiTierSlug(for tierId: String) -> String {
        switch tierId {
        case "starter": return "starter"
        case "plus", "core": return "core"
        default: return "unlimited"   // premium / elite -> unlimited
        }
    }

    private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func disciplineDisplay(_ raw: String) -> String {
        raw.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func dayName(_ i: Int) -> String {
        (i >= 0 && i < dayNames.count) ? dayNames[i] : "Mon"
    }

    /// "06:00" -> "6:00 AM"
    static func timeDisplay(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return hhmm }
        let ampm = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, ampm)
    }

    // MARK: - Auth

    func login(email: String, password: String) async {
        await runAuth { try await SolmoveAPI.shared.login(email: email, password: password) }
    }

    func register(email: String, password: String, name: String, role: Role) async {
        let apiRole: String = role == .member ? "MEMBER" : role == .instructor ? "INSTRUCTOR" : "STUDIO_ADMIN"
        await runAuth { try await SolmoveAPI.shared.register(email: email, password: password, name: name, role: apiRole) }
    }

    private func runAuth(_ authCall: () async throws -> APIUser) async {
        isLoading = true; authError = nil
        do {
            let user = try await authCall()
            currentUserName = user.name
            role = Store.role(from: user.role)
            try await loadEverything()
            isAuthenticated = true
            isOnline = true
        } catch {
            authError = (error as? SolmoveAPI.APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    static func role(from apiRole: String) -> Role {
        switch apiRole {
        case "INSTRUCTOR": return .instructor
        case "STUDIO_ADMIN": return .studio
        default: return .member
        }
    }

    // MARK: - Loading

    func loadEverything() async throws {
        async let studiosR = SolmoveAPI.shared.fetchStudios()
        async let instrR = SolmoveAPI.shared.fetchInstructors()
        async let classesR = SolmoveAPI.shared.fetchClasses()
        let (apiStudios, apiInstr, apiClasses) = try await (studiosR, instrR, classesR)

        studios = apiStudios.map {
            Studio(id: $0.id, name: $0.name, neighborhood: $0.neighborhood,
                   badges: $0.foundingPartner ? ["founding"] : [],
                   rating: $0.rating > 0 ? $0.rating : 4.7, credits: 7,
                   lat: $0.lat, lon: $0.lon)
        }
        instructors = apiInstr.map {
            Instructor(id: $0.id, name: $0.name,
                       disciplines: $0.disciplines.map(Store.disciplineDisplay),
                       badges: [], score: $0.rating > 0 ? $0.rating : 4.7,
                       shiftsCovered: $0.shiftsCovered ?? 0)
        }
        classes = apiClasses.map {
            GymClass(id: $0.id, studioId: $0.studioId, title: $0.title,
                     instructor: $0.instructorId ?? "",
                     day: Store.dayName($0.dayOfWeek), time: Store.timeDisplay($0.time),
                     spots: $0.capacity, booked: $0.booked ?? 0)
        }

        // Resolve persona identity (managed studio / instructor id).
        if let me = try? await SolmoveAPI.shared.me() {
            currentInstructorId = me.instructor?.id ?? currentInstructorId
            managedStudioId = me.studioAdminOf?.first?.studio.id
        }

        // Best-effort: load real messaging threads for studio/instructor personas.
        if role != .member { try? await loadThreads() }
    }

    private func loadThreads() async throws {
        let apiThreads = try await SolmoveAPI.shared.fetchThreads()
        var newThreads: [MessageThread] = []
        var newMessages: [Message] = []
        for t in apiThreads {
            newThreads.append(MessageThread(id: t.id, studioId: t.studioId, instructorId: t.instructorId))
            // Fetch full message history for each thread.
            if let full = try? await SolmoveAPI.shared.fetchThread(id: t.id), let msgs = full.messages {
                for m in msgs {
                    newMessages.append(Message(id: m.id, threadId: t.id,
                                               senderRole: m.senderRole == "INSTRUCTOR" ? .instructor : .studio,
                                               text: m.text, ts: Store.parseDate(m.createdAt)))
                }
            }
        }
        threads = newThreads
        messages = newMessages
    }

    static func parseDate(_ iso: String) -> Double {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: iso) { return d.timeIntervalSince1970 }
        let fmt2 = ISO8601DateFormatter()
        return fmt2.date(from: iso)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    }

    // MARK: - Session control

    func continueOffline() {
        isOnline = false
        isAuthenticated = true      // let the user into the demo
    }

    func logout() {
        Task { await SolmoveAPI.shared.logout() }
        isAuthenticated = false
        isOnline = false
        currentUserName = ""
        managedStudioId = nil
        authError = nil
        reset()   // back to local seed
    }
}
