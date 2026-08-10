import SwiftUI

// MARK: - Studio Dashboard
struct StudioDashboardView: View {
    @EnvironmentObject var store: Store
    @State private var showPost = false

    // Demo: the studio user manages the first studio.
    var studio: Studio? { store.studios.first }

    var body: some View {
        VStack(spacing: 12) {
            if let studio {
                let cls = store.classes(for: studio.id)
                let bookedCount = cls.reduce(0) { $0 + store.occupancy($1) }
                let payout = Double(bookedCount) * ClassEcon.studioPayout
                let cpPayout = Double(bookedCount) * ClassEcon.classPassPayout

                SectionTitle(title: studio.name, subtitle: studio.neighborhood)
                HStack(spacing: 12) {
                    KPI(value: "\(bookedCount)", label: "Bookings this week")
                    KPI(value: money(payout), label: "Your payout (\(pct(Model.studioPayoutPct)))")
                }
                Card {
                    Text("You keep \(money(payout - cpPayout)) more than the ClassPass benchmark on the same bookings. A \(pct(Model.platformFeePct)) platform fee (\(money(Double(bookedCount) * ClassEcon.platformFee))) applies studio-side.")
                        .font(.caption).foregroundColor(Palette.muted(store.lightMode))
                }

                SectionTitle(title: "Your classes")
                ForEach(cls) { c in
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title).font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                                Text("\(c.day) · \(c.time)").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                            }
                            Spacer()
                            Text("\(store.occupancy(c))/\(c.spots)").font(.caption.bold()).foregroundColor(Palette.accent)
                        }
                    }
                }

                SectionTitle(title: "Sub shifts")
                Button { showPost = true } label: {
                    Label("Post a sub shift", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Palette.accent.opacity(0.18)).foregroundColor(Palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                ForEach(store.shifts) { shift in ShiftCard(shift: shift, showClaimant: true) }
            }
        }
        .sheet(isPresented: $showPost) { PostShiftSheet(studioId: studio?.id ?? "st1") }
    }
}

struct PostShiftSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let studioId: String
    @State private var title = ""
    @State private var discipline = "Yoga"
    @State private var day = "Mon"
    @State private var time = "6:00 AM"
    let disciplines = ["Yoga","Hot Yoga","Cycle","Pilates","Strength"]
    let days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Shift title (e.g. Sub: Vinyasa Flow)", text: $title)
                Picker("Discipline", selection: $discipline) { ForEach(disciplines, id: \.self) { Text($0) } }
                Picker("Day", selection: $day) { ForEach(days, id: \.self) { Text($0) } }
                TextField("Time", text: $time)
            }
            .navigationTitle("Post Shift")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        store.postShift(studioId: studioId,
                                        title: title.isEmpty ? "Sub: \(discipline)" : title,
                                        discipline: discipline, day: day, time: time)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShiftCard: View {
    @EnvironmentObject var store: Store
    let shift: Shift
    var showClaimant = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.title).font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                        Text("\(shift.discipline) · \(shift.day) · \(shift.time)")
                            .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                    }
                    Spacer()
                    Text(shift.status == "open" ? "Open" : "Filled")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((shift.status == "open" ? Palette.accent2 : Color.green).opacity(0.18))
                        .foregroundColor(shift.status == "open" ? Palette.accent2 : .green)
                        .clipShape(Capsule())
                }
                if shift.status == "filled", showClaimant, let by = shift.claimedBy, let instr = store.instructor(by) {
                    Text("Covered by \(instr.name) · ⭐ \(store.scoreText(instr))")
                        .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                }
                Card {
                    Text("Studio cost \(money(ShiftEcon.studioCostPerShift)) = \(money(Model.avgShiftPay)) instructor + \(money(ShiftEcon.feePerShift)) fee · \(money(ShiftEcon.studioSavingsPerShift)) under direct hire")
                        .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                }
                if store.role == .instructor && shift.status == "open" {
                    Button { store.claimShift(shift) } label: {
                        Text("Claim shift · get \(money(Model.avgShiftPay))")
                            .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(Palette.accent.opacity(0.18)).foregroundColor(Palette.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

// MARK: - Instructors leaderboard
struct InstructorsView: View {
    @EnvironmentObject var store: Store
    var sorted: [Instructor] { store.instructors.sorted { store.instructorScore($0) > store.instructorScore($1) } }

    var body: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "Instructor marketplace", subtitle: "Ranked by member + studio reputation")
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, instr in
                NavigationLink { InstructorProfileView(instructor: instr) } label: {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(idx + 1)").font(.caption.bold()).foregroundColor(Palette.accent2)
                                Avatar(name: instr.name, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instr.name).font(.headline).foregroundColor(Palette.text(store.lightMode))
                                    Text("Lvl \(store.instructorLevel(instr)) · \(store.levelTitle(instr)) · \(instr.disciplines.joined(separator: " · "))")
                                        .font(.caption).foregroundColor(Palette.muted(store.lightMode))
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("⭐ \(store.scoreText(instr))").font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                                    Text("\(instr.shiftsCovered) shifts").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                                }
                            }
                            if !instr.badges.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(instr.badges, id: \.self) { b in
                                            if let badge = INSTRUCTOR_BADGES[b] { Pill(text: "\(badge.icon) \(badge.label)") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Instructor shifts feed
struct ShiftsView: View {
    @EnvironmentObject var store: Store
    var open: [Shift] { store.shifts.filter { $0.status == "open" } }
    var mine: [Shift] { store.shifts.filter { $0.claimedBy == store.currentInstructorId } }

    var body: some View {
        VStack(spacing: 12) {
            if let me = store.me {
                Card {
                    HStack(spacing: 12) {
                        CircularXPRing(instructor: me)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(me.name).font(.headline).foregroundColor(Palette.text(store.lightMode))
                            Text("\(store.levelTitle(me)) · ⭐ \(store.scoreText(me)) · \(me.shiftsCovered) shifts")
                                .font(.caption).foregroundColor(Palette.muted(store.lightMode))
                            if let xp = store.xpToNext(me) {
                                Text("\(xp) XP to Lvl \(store.instructorLevel(me) + 1)")
                                    .font(.caption2).foregroundStyle(Palette.brand)
                            } else {
                                Text("Max level reached 🏆").font(.caption2).foregroundStyle(Palette.brand)
                            }
                        }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(money(Model.avgShiftPay)).font(.title3.bold()).foregroundStyle(Palette.brand)
                            Text("/shift").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                        }
                    }
                }
            }
            SectionTitle(title: "Open shifts", subtitle: "\(open.count) available")
            if open.isEmpty {
                Card { Text("No open shifts right now. Check back soon.").font(.subheadline).foregroundColor(Palette.muted(store.lightMode)) }
            } else {
                ForEach(open) { shift in ShiftCard(shift: shift) }
            }
            if !mine.isEmpty {
                SectionTitle(title: "Your covered shifts")
                ForEach(mine) { shift in ShiftCard(shift: shift) }
            }
        }
    }
}

// MARK: - Economics (studio only)
struct EconomicsView: View {
    @EnvironmentObject var store: Store

    // Illustrative members per tier for the revenue table (mirrors web app).
    let membersPerTier: [String: Int] = ["starter": 500, "plus": 400, "core": 350, "premium": 150, "elite": 60]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                KPI(value: pct(Model.studioPayoutPct), label: "Studio payout", sub: "of \(money0(Model.dropInRate)) drop-in")
                KPI(value: String(format: "%.2f×", Model.studioPayoutPct / Model.classPassPayoutPct), label: "vs ClassPass payout")
            }
            HStack(spacing: 12) {
                KPI(value: money(ClassEcon.studioPayout), label: "You earn / class")
                KPI(value: money(ClassEcon.classPassPayout), label: "ClassPass / class")
            }

            SectionTitle(title: "Membership revenue")
            Card {
                VStack(spacing: 0) {
                    HStack {
                        Text("Tier").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Members").frame(width: 70, alignment: .trailing)
                        Text("Revenue").frame(width: 90, alignment: .trailing)
                    }.font(.caption.bold()).foregroundColor(Palette.muted(store.lightMode))
                    Divider().background(Palette.line(store.lightMode))
                    ForEach(TIERS) { tier in
                        let members = membersPerTier[tier.id] ?? 0
                        let rev = Double(members * tier.price)
                        HStack {
                            Text(tier.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(members)").frame(width: 70, alignment: .trailing)
                            Text(money0(rev)).frame(width: 90, alignment: .trailing)
                        }.font(.caption).foregroundColor(Palette.text(store.lightMode)).padding(.vertical, 6)
                        Divider().background(Palette.line(store.lightMode))
                    }
                    let total = TIERS.reduce(0.0) { $0 + Double((membersPerTier[$1.id] ?? 0) * $1.price) }
                    HStack {
                        Text("Total MRR").frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                        Text(money0(total)).foregroundStyle(Palette.brand)
                    }.font(.subheadline.bold()).padding(.top, 6)
                }
            }

            SectionTitle(title: "Instructor marketplace")
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    econRow("Instructor pay / shift", money(Model.avgShiftPay))
                    econRow("Placement fee (studio, \(pct(Model.placementFeePct)))", money(ShiftEcon.feePerShift))
                    econRow("Studio cost / shift", money(ShiftEcon.studioCostPerShift))
                    econRow("Direct-hire cost / shift", money(Model.directHireCostPerShift))
                    Divider().background(Palette.line(store.lightMode))
                    econRow("Studio savings / shift", money(ShiftEcon.studioSavingsPerShift), highlight: true)
                }
            }

            Card {
                Text("On a \(money0(Model.dropInRate)) drop-in class, a studio earns \(money(ClassEcon.studioPayout)) here vs \(money(ClassEcon.classPassPayout)) on ClassPass — a \(String(format: "%.2f×", Model.studioPayoutPct / Model.classPassPayoutPct)) payout multiple. Instructors are always paid in full; the placement fee is charged to the studio, never the instructor.")
                    .font(.caption).foregroundColor(Palette.muted(store.lightMode))
            }

            Button(role: .destructive) { store.reset() } label: {
                Label("Reset demo data", systemImage: "arrow.counterclockwise")
                    .font(.caption).frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private func econRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(Palette.muted(store.lightMode))
            Spacer()
            Text(value).font(.caption.bold())
                .foregroundColor(highlight ? Palette.accent2 : Palette.text(store.lightMode))
        }
    }
}
