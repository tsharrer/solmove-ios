import Foundation

// ============================================================
// Solmove — Wellness Marketplace
// Model constants ported directly from the web app's data.js,
// which pulls from "Wellness Marketplace Financial Model.xlsx".
// ============================================================

enum Model {
    static let dropInRate = 25.0            // Avg boutique studio drop-in rate ($)
    static let creditsPerClass = 7          // Avg credits required per class
    static let studioPayoutPct = 0.40       // Solmove differentiator vs ClassPass (0.275)
    static let classPassPayoutPct = 0.275   // Benchmark
    static let platformFeePct = 0.05        // 5% studio-side "safety net" fee

    static let avgShiftPay = 35.0           // Paid in full to instructor, never discounted
    static let placementFeePct = 0.20       // Charged to studio, not instructor
    static let directHireCostPerShift = 45.0
    static let paymentProcessingPct = 0.029
}

enum ClassEcon {
    static let studioPayout = Model.dropInRate * Model.studioPayoutPct                       // $10.00
    static let platformFee = Model.dropInRate * Model.studioPayoutPct * Model.platformFeePct // $0.50
    static let classPassPayout = Model.dropInRate * Model.classPassPayoutPct                 // $6.875
}

enum ShiftEcon {
    static let feePerShift = Model.avgShiftPay * Model.placementFeePct                        // $7
    static let studioCostPerShift = Model.avgShiftPay * (1 + Model.placementFeePct)           // $42
    static let studioSavingsPerShift = Model.directHireCostPerShift - Model.avgShiftPay * (1 + Model.placementFeePct) // $3
}

// ---- Membership tiers ----
struct Tier: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let price: Int
    let credits: Int
    var popular: Bool = false
}

let TIERS: [Tier] = [
    Tier(id: "starter", name: "Starter", price: 19,  credits: 8),
    Tier(id: "plus",    name: "Plus",    price: 35,  credits: 15),
    Tier(id: "core",    name: "Core",    price: 69,  credits: 33, popular: true),
    Tier(id: "premium", name: "Premium", price: 139, credits: 68),
    Tier(id: "elite",   name: "Elite",   price: 199, credits: 100),
]

// ---- Badges ----
struct Badge { let label: String; let icon: String }

let INSTRUCTOR_BADGES: [String: Badge] = [
    "studioRated": Badge(label: "Highly Rated by Studios", icon: "⭐"),
    "memberRated": Badge(label: "Highly Rated by Members", icon: "💜"),
    "reliable":    Badge(label: "Most Reliable", icon: "⚡"),
    "mostShifts":  Badge(label: "Most Shifts Covered", icon: "🏅"),
]

let STUDIO_BADGES: [String: Badge] = [
    "topRated": Badge(label: "Top Rated by Instructors", icon: "🌟"),
    "founding": Badge(label: "Founding Studio", icon: "🏛️"),
]

// ---- Domain models ----
struct Studio: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var neighborhood: String
    var badges: [String]
    var rating: Double
    var credits: Int
    var lat: Double? = nil
    var lon: Double? = nil
}

struct GymClass: Identifiable, Codable, Hashable {
    let id: String
    let studioId: String
    var title: String
    var instructor: String   // instructor id
    var day: String
    var time: String
    var spots: Int
    var booked: Int          // recurring weekly baseline
}

struct Instructor: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var disciplines: [String]
    var badges: [String]
    var score: Double
    var shiftsCovered: Int
}

struct Shift: Identifiable, Codable, Hashable {
    let id: String
    let studioId: String
    var title: String
    var discipline: String
    var day: String
    var time: String
    var status: String       // open | filled
    var claimedBy: String?
}

// ---- Seed data (Houston launch) ----
enum Seed {
    static let studios: [Studio] = [
        Studio(id: "st1", name: "Bayou Yoga Collective", neighborhood: "The Heights",  badges: ["founding","topRated"], rating: 4.9, credits: 7, lat: 29.7989, lon: -95.4103),
        Studio(id: "st2", name: "Montrose Cycle Lab",    neighborhood: "Montrose",     badges: ["founding"],            rating: 4.7, credits: 9, lat: 29.7450, lon: -95.3903),
        Studio(id: "st3", name: "Rice Village Pilates",  neighborhood: "Rice Village", badges: ["topRated"],            rating: 4.8, credits: 8, lat: 29.7176, lon: -95.4145),
        Studio(id: "st4", name: "EaDo Strength Club",    neighborhood: "EaDo",         badges: [],                      rating: 4.6, credits: 6, lat: 29.7480, lon: -95.3510),
        Studio(id: "st5", name: "Galleria Hot Yoga",     neighborhood: "Galleria",     badges: ["founding"],            rating: 4.5, credits: 7, lat: 29.7397, lon: -95.4614),
    ]

    static let classes: [GymClass] = [
        GymClass(id: "c1", studioId: "st1", title: "Vinyasa Flow",        instructor: "in1", day: "Mon", time: "6:00 AM",  spots: 12, booked: 4),
        GymClass(id: "c2", studioId: "st1", title: "Restorative Yin",     instructor: "in2", day: "Mon", time: "7:00 PM",  spots: 15, booked: 9),
        GymClass(id: "c3", studioId: "st2", title: "Rhythm Ride 45",      instructor: "in3", day: "Tue", time: "5:30 PM",  spots: 24, booked: 20),
        GymClass(id: "c4", studioId: "st3", title: "Reformer Sculpt",     instructor: "in4", day: "Wed", time: "9:00 AM",  spots: 10, booked: 7),
        GymClass(id: "c5", studioId: "st4", title: "Barbell Strength",    instructor: "in5", day: "Wed", time: "6:00 PM",  spots: 14, booked: 6),
        GymClass(id: "c6", studioId: "st5", title: "Hot 26",              instructor: "in2", day: "Thu", time: "6:30 AM",  spots: 30, booked: 18),
        GymClass(id: "c7", studioId: "st2", title: "Climb & Sprint",      instructor: "in3", day: "Fri", time: "12:00 PM", spots: 24, booked: 11),
        GymClass(id: "c8", studioId: "st3", title: "Mat Pilates Express", instructor: "in4", day: "Sat", time: "8:00 AM",  spots: 16, booked: 15),
    ]

    static let instructors: [Instructor] = [
        Instructor(id: "in1", name: "Maya Torres",   disciplines: ["Yoga"],            badges: ["studioRated","reliable"],   score: 4.9, shiftsCovered: 42),
        Instructor(id: "in2", name: "Devon Clarke",  disciplines: ["Yoga","Hot Yoga"], badges: ["memberRated","mostShifts"], score: 4.8, shiftsCovered: 61),
        Instructor(id: "in3", name: "Priya Nair",    disciplines: ["Cycle"],           badges: ["reliable"],                 score: 4.7, shiftsCovered: 28),
        Instructor(id: "in4", name: "Sam Whitfield", disciplines: ["Pilates"],         badges: ["studioRated","memberRated"],score: 4.9, shiftsCovered: 37),
        Instructor(id: "in5", name: "Jordan Lee",    disciplines: ["Strength"],        badges: [],                           score: 4.5, shiftsCovered: 12),
    ]

    static let shifts: [Shift] = [
        Shift(id: "sh1", studioId: "st1", title: "Sub: Vinyasa Flow",    discipline: "Yoga",     day: "Mon", time: "6:00 AM", status: "open",   claimedBy: nil),
        Shift(id: "sh2", studioId: "st2", title: "Sub: Rhythm Ride 45",  discipline: "Cycle",    day: "Tue", time: "5:30 PM", status: "open",   claimedBy: nil),
        Shift(id: "sh3", studioId: "st5", title: "Sub: Hot 26",          discipline: "Hot Yoga", day: "Thu", time: "6:30 AM", status: "open",   claimedBy: nil),
        Shift(id: "sh4", studioId: "st4", title: "Sub: Barbell Strength",discipline: "Strength", day: "Fri", time: "6:00 PM", status: "filled", claimedBy: "in5"),
    ]
}

// ---- Formatting helpers ----
func money(_ v: Double) -> String {
    if v == v.rounded() { return "$\(Int(v))" }
    return String(format: "$%.2f", v)
}
func money0(_ v: Double) -> String { "$\(Int(v.rounded()))" }
func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
