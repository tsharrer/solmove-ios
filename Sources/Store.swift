import Foundation
import SwiftUI

enum Role: String, Codable, CaseIterable {
    case member, studio, instructor
    var label: String {
        switch self {
        case .member: return "Member"
        case .studio: return "Studio"
        case .instructor: return "Instructor"
        }
    }
    var icon: String {
        switch self {
        case .member: return "person.fill"
        case .studio: return "building.2.fill"
        case .instructor: return "figure.yoga"
        }
    }
}

private struct PersistedState: Codable {
    var role: Role
    var tierId: String?
    var bookings: [String]                 // class ids booked
    var memberRatings: [String: [Int]]     // instructorId -> stars
    var studioRatings: [String: [Int]]     // studioId -> stars
    var studios: [Studio]
    var classes: [GymClass]
    var instructors: [Instructor]
    var shifts: [Shift]
    var currentInstructorId: String        // "who am I" when in instructor role
    var lightMode: Bool
    var favStudios: [String]?              // studioIds the member favorites
    var favInstructors: [String]?          // instructorIds the member follows
}

@MainActor
final class Store: ObservableObject {
    static let key = "solmove.v2"
    private let RATING_WEIGHT = 20.0

    @Published var role: Role = .member
    @Published var tierId: String? = nil
    @Published var bookings: Set<String> = []
    @Published var memberRatings: [String: [Int]] = [:]
    @Published var studioRatings: [String: [Int]] = [:]
    @Published var studios: [Studio] = Seed.studios
    @Published var classes: [GymClass] = Seed.classes
    @Published var instructors: [Instructor] = Seed.instructors
    @Published var shifts: [Shift] = Seed.shifts
    @Published var currentInstructorId: String = "in1"
    @Published var lightMode: Bool = false
    @Published var favStudios: Set<String> = []
    @Published var favInstructors: Set<String> = []


    init() { load() }

    // MARK: - Lookups
    func studio(_ id: String) -> Studio? { studios.first { $0.id == id } }
    func instructor(_ id: String) -> Instructor? { instructors.first { $0.id == id } }
    func classes(for studioId: String) -> [GymClass] { classes.filter { $0.studioId == studioId } }
    var currentTier: Tier? { TIERS.first { $0.id == tierId } }
    var me: Instructor? { instructor(currentInstructorId) }
    /// The studio managed by the current studio-persona (demo: the first studio).
    var managedStudio: Studio? { studios.first }

    // MARK: - "Teaches at" graph
    /// Every studio where an instructor holds a recurring class or has covered a shift.
    func studiosTeaching(_ instructorId: String) -> [Studio] {
        var ids = Set(classes.filter { $0.instructor == instructorId }.map { $0.studioId })
        ids.formUnion(shifts.filter { $0.claimedBy == instructorId }.map { $0.studioId })
        return studios.filter { ids.contains($0.id) }
    }
    /// Distinct instructors who teach at a studio (classes + covered shifts).
    func instructorsTeaching(at studioId: String) -> [Instructor] {
        var ids = Set(classes.filter { $0.studioId == studioId }.map { $0.instructor })
        ids.formUnion(shifts.filter { $0.studioId == studioId && $0.claimedBy != nil }.compactMap { $0.claimedBy })
        return instructors.filter { ids.contains($0.id) }
    }
    /// Instructors the current member has booked classes with.
    var myInstructors: [Instructor] {
        let ids = Set(classes.filter { bookings.contains($0.id) }.map { $0.instructor })
        return instructors.filter { ids.contains($0.id) }
    }
    /// Distinct studios the member has booked into.
    var myStudios: [Studio] {
        let ids = Set(classes.filter { bookings.contains($0.id) }.map { $0.studioId })
        return studios.filter { ids.contains($0.id) }
    }

    // MARK: - Economics / reputation
    func instructorScore(_ instr: Instructor) -> Double {
        let stars = memberRatings[instr.id] ?? []
        let sum = stars.reduce(0, +)
        return (instr.score * RATING_WEIGHT + Double(sum)) / (RATING_WEIGHT + Double(stars.count))
    }
    func scoreText(_ instr: Instructor) -> String { String(format: "%.1f", instructorScore(instr)) }

    /// Blended studio rating: seed rating + member star ratings.
    func studioScore(_ studio: Studio) -> Double {
        let stars = studioRatings[studio.id] ?? []
        let sum = stars.reduce(0, +)
        return (studio.rating * RATING_WEIGHT + Double(sum)) / (RATING_WEIGHT + Double(stars.count))
    }
    func studioScoreText(_ studio: Studio) -> String { String(format: "%.1f", studioScore(studio)) }

    // MARK: - Favorites / following
    func isFavStudio(_ id: String) -> Bool { favStudios.contains(id) }
    func isFavInstructor(_ id: String) -> Bool { favInstructors.contains(id) }
    func toggleFavStudio(_ id: String) {
        if favStudios.contains(id) { favStudios.remove(id) } else { favStudios.insert(id) }
        save()
    }
    func toggleFavInstructor(_ id: String) {
        if favInstructors.contains(id) { favInstructors.remove(id) } else { favInstructors.insert(id) }
        save()
    }
    var favoriteStudios: [Studio] { studios.filter { favStudios.contains($0.id) } }
    var favoriteInstructors: [Instructor] { instructors.filter { favInstructors.contains($0.id) } }

    /// Gamified follower counts: a stable base derived from reputation + the member's own follow.
    func followers(studio: Studio) -> Int {
        Int(studio.rating * 220) + (studio.badges.contains("founding") ? 140 : 0) + (isFavStudio(studio.id) ? 1 : 0)
    }
    func followers(instructor: Instructor) -> Int {
        instructor.shiftsCovered * 18 + Int(instructor.score * 40) + (isFavInstructor(instructor.id) ? 1 : 0)
    }

    func occupancy(_ cls: GymClass) -> Int {
        cls.booked + (bookings.contains(cls.id) ? 1 : 0)
    }

    // MARK: - Gamification (instructor "play")
    static let levelThresholds = [0, 300, 800, 1600, 3000]
    static let levelTitles = ["Rookie", "Regular", "Pro", "Elite", "Legend"]

    /// XP earned from shifts covered and member love.
    func instructorXP(_ instr: Instructor) -> Int {
        let stars = (memberRatings[instr.id] ?? []).reduce(0, +)
        return instr.shiftsCovered * 80 + stars * 12
    }
    func instructorLevel(_ instr: Instructor) -> Int {
        let xp = instructorXP(instr)
        return max(1, Store.levelThresholds.lastIndex(where: { xp >= $0 }).map { $0 + 1 } ?? 1)
    }
    func levelTitle(_ instr: Instructor) -> String {
        Store.levelTitles[min(instructorLevel(instr), Store.levelTitles.count) - 1]
    }
    /// Progress 0…1 toward the next level (1.0 when maxed).
    func levelProgress(_ instr: Instructor) -> Double {
        let xp = instructorXP(instr)
        let lvl = instructorLevel(instr)
        if lvl >= Store.levelThresholds.count { return 1 }
        let cur = Store.levelThresholds[lvl - 1], next = Store.levelThresholds[lvl]
        return min(1, Double(xp - cur) / Double(next - cur))
    }
    func xpToNext(_ instr: Instructor) -> Int? {
        let lvl = instructorLevel(instr)
        if lvl >= Store.levelThresholds.count { return nil }
        return Store.levelThresholds[lvl] - instructorXP(instr)
    }
    /// Rank in the reputation leaderboard (1-based).
    func rank(_ instr: Instructor) -> Int {
        let sorted = instructors.sorted { instructorScore($0) > instructorScore($1) }
        return (sorted.firstIndex(where: { $0.id == instr.id }) ?? 0) + 1
    }

    struct Achievement: Identifiable { let id: String; let icon: String; let label: String; let unlocked: Bool }

    func instructorAchievements(_ instr: Instructor) -> [Achievement] {
        let venues = studiosTeaching(instr.id).count
        return [
            Achievement(id: "first", icon: "figure.walk", label: "First Shift", unlocked: instr.shiftsCovered >= 1),
            Achievement(id: "ten", icon: "flame.fill", label: "10 Shifts", unlocked: instr.shiftsCovered >= 10),
            Achievement(id: "vet", icon: "shield.fill", label: "Veteran · 40", unlocked: instr.shiftsCovered >= 40),
            Achievement(id: "fav", icon: "heart.fill", label: "Crowd Favorite", unlocked: instructorScore(instr) >= 4.8),
            Achievement(id: "road", icon: "map.fill", label: "Road Warrior · 3 venues", unlocked: venues >= 3),
            Achievement(id: "century", icon: "crown.fill", label: "Century · 100", unlocked: instr.shiftsCovered >= 100),
        ]
    }
    func studioAchievements(_ studio: Studio) -> [Achievement] {
        let roster = instructorsTeaching(at: studio.id).count
        let full = classes(for: studio.id).contains { occupancy($0) >= $0.spots }
        return [
            Achievement(id: "founding", icon: "building.columns.fill", label: "Founding Studio", unlocked: studio.badges.contains("founding")),
            Achievement(id: "fav", icon: "star.fill", label: "Crowd Favorite", unlocked: studioScore(studio) >= 4.8),
            Achievement(id: "full", icon: "person.3.fill", label: "Full House", unlocked: full),
            Achievement(id: "roster", icon: "figure.yoga", label: "Big Roster · 3+", unlocked: roster >= 3),
        ]
    }
    func memberAchievements() -> [Achievement] {
        let studioCount = myStudios.count
        let ratingsGiven = memberRatings.values.reduce(0) { $0 + $1.count } + studioRatings.values.reduce(0) { $0 + $1.count }
        return [
            Achievement(id: "first", icon: "sparkles", label: "First Class", unlocked: bookings.count >= 1),
            Achievement(id: "regular", icon: "flame.fill", label: "Regular · 5 classes", unlocked: bookings.count >= 5),
            Achievement(id: "explorer", icon: "map.fill", label: "Explorer · 3 studios", unlocked: studioCount >= 3),
            Achievement(id: "critic", icon: "star.bubble.fill", label: "Critic · 3 ratings", unlocked: ratingsGiven >= 3),
        ]
    }

    // MARK: - Actions
    func subscribe(_ tier: Tier) { tierId = tier.id; save() }

    func isBooked(_ cls: GymClass) -> Bool { bookings.contains(cls.id) }

    func toggleBooking(_ cls: GymClass) {
        if bookings.contains(cls.id) { bookings.remove(cls.id) }
        else { bookings.insert(cls.id) }
        save()
    }

    func rate(instructorId: String, stars: Int) {
        memberRatings[instructorId, default: []].append(stars)
        // award memberRated badge at >= 4.85, mirroring web app
        if let idx = instructors.firstIndex(where: { $0.id == instructorId }),
           instructorScore(instructors[idx]) >= 4.85,
           !instructors[idx].badges.contains("memberRated") {
            instructors[idx].badges.append("memberRated")
        }
        save()
    }

    func rateStudio(studioId: String, stars: Int) {
        studioRatings[studioId, default: []].append(stars)
        if let idx = studios.firstIndex(where: { $0.id == studioId }),
           studioScore(studios[idx]) >= 4.85,
           !studios[idx].badges.contains("topRated") {
            studios[idx].badges.append("topRated")
        }
        save()
    }

    func claimShift(_ shift: Shift) {
        guard let idx = shifts.firstIndex(where: { $0.id == shift.id }) else { return }
        shifts[idx].status = "filled"
        shifts[idx].claimedBy = currentInstructorId
        if let iidx = instructors.firstIndex(where: { $0.id == currentInstructorId }) {
            instructors[iidx].shiftsCovered += 1
        }
        save()
    }

    func postShift(studioId: String, title: String, discipline: String, day: String, time: String) {
        let id = "sh\(Int(Date().timeIntervalSince1970))"
        shifts.insert(Shift(id: id, studioId: studioId, title: title, discipline: discipline,
                            day: day, time: time, status: "open", claimedBy: nil), at: 0)
        save()
    }

    func addStudio(name: String, neighborhood: String) {
        let id = "st\(Int(Date().timeIntervalSince1970))"
        // Scatter new studios around downtown Houston so they show on the map.
        let jLat = Double.random(in: -0.03...0.03)
        let jLon = Double.random(in: -0.03...0.03)
        studios.append(Studio(id: id, name: name, neighborhood: neighborhood,
                              badges: ["founding"], rating: 5.0, credits: 7,
                              lat: 29.7604 + jLat, lon: -95.3698 + jLon))
        role = .studio
        save()
    }

    func addInstructor(name: String, discipline: String) {
        let id = "in\(Int(Date().timeIntervalSince1970))"
        instructors.append(Instructor(id: id, name: name, disciplines: [discipline],
                                      badges: [], score: 5.0, shiftsCovered: 0))
        currentInstructorId = id
        role = .instructor
        save()
    }

    func setRole(_ r: Role) { role = r; save() }
    func toggleTheme() { lightMode.toggle(); save() }

    func reset() {
        tierId = nil; bookings = []; memberRatings = [:]; studioRatings = [:]
        studios = Seed.studios; classes = Seed.classes
        instructors = Seed.instructors; shifts = Seed.shifts
        currentInstructorId = "in1"; role = .member
        favStudios = []; favInstructors = []
        save()
    }

    // MARK: - Persistence
    private func save() {
        let state = PersistedState(role: role, tierId: tierId, bookings: Array(bookings),
                                   memberRatings: memberRatings, studioRatings: studioRatings,
                                   studios: studios, classes: classes,
                                   instructors: instructors, shifts: shifts,
                                   currentInstructorId: currentInstructorId, lightMode: lightMode,
                                   favStudios: Array(favStudios), favInstructors: Array(favInstructors))
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Store.key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Store.key),
              let s = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        role = s.role; tierId = s.tierId; bookings = Set(s.bookings)
        memberRatings = s.memberRatings; studioRatings = s.studioRatings
        studios = s.studios; classes = s.classes
        instructors = s.instructors; shifts = s.shifts
        currentInstructorId = s.currentInstructorId; lightMode = s.lightMode
        favStudios = Set(s.favStudios ?? []); favInstructors = Set(s.favInstructors ?? [])
    }
}
