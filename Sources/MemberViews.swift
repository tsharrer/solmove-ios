import SwiftUI

// MARK: - Home (role-aware hero)
struct HomeView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Pill(text: "Houston · Boutique wellness")
                    Text(heroTitle)
                        .font(.title.bold())
                        .foregroundColor(Palette.text(store.lightMode))
                    Text(heroSub)
                        .font(.subheadline)
                        .foregroundColor(Palette.muted(store.lightMode))
                }
            }

            HStack(spacing: 12) {
                KPI(value: pct(Model.studioPayoutPct), label: "Studio payout of drop-in")
                KPI(value: "\(TIERS.count)", label: "Membership tiers")
            }
            HStack(spacing: 12) {
                KPI(value: money(ShiftEcon.studioSavingsPerShift), label: "Saved per sub shift")
                KPI(value: "\(store.studios.count)", label: "Partner studios")
            }

            if store.role == .member {
                SectionTitle(title: "Popular this week")
                ForEach(store.classes.prefix(4)) { cls in ClassRow(cls: cls) }
            }
        }
    }

    private var heroTitle: String {
        switch store.role {
        case .member: return "One membership. Every studio."
        case .studio: return "Keep 40% of every drop-in."
        case .instructor: return "Get paid in full. Every shift."
        }
    }
    private var heroSub: String {
        switch store.role {
        case .member: return "Book yoga, cycle, pilates and strength across Houston with a single credit-based membership."
        case .studio: return "Solmove pays studios \(pct(Model.studioPayoutPct)) of the drop-in rate vs \(pct(Model.classPassPayoutPct)) on ClassPass — plus a fair instructor marketplace."
        case .instructor: return "Claim open sub shifts. Instructors are always paid \(money(Model.avgShiftPay)) in full — the placement fee is charged to the studio, never you."
        }
    }
}

// MARK: - Discover
struct DiscoverView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "Studios", subtitle: "\(store.studios.count) partners near you")
            ForEach(store.studios) { studio in
                NavigationLink { StudioDetailView(studio: studio) } label: {
                    StudioCard(studio: studio)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct StudioCard: View {
    @EnvironmentObject var store: Store
    let studio: Studio
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(studio.name).font(.headline).foregroundColor(Palette.text(store.lightMode))
                        Text(studio.neighborhood).font(.caption).foregroundColor(Palette.muted(store.lightMode))
                    }
                    Spacer()
                    HStack(spacing: 4) { Stars(value: studio.rating); Text(String(format: "%.1f", studio.rating)).font(.caption).foregroundColor(Palette.muted(store.lightMode)) }
                }
                if !studio.badges.isEmpty {
                    HStack {
                        ForEach(studio.badges, id: \.self) { b in
                            if let badge = STUDIO_BADGES[b] { Pill(text: "\(badge.icon) \(badge.label)") }
                        }
                    }
                }
                Text("\(studio.credits) credits / class").font(.caption).foregroundColor(Palette.accent2)
            }
        }
    }
}

struct StudioDetailView: View {
    @EnvironmentObject var store: Store
    let studio: Studio
    var body: some View {
        ThemedScreen {
            StudioProfileContent(studio: studio)
        }
        .navigationTitle(studio.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Class row with booking
struct ClassRow: View {
    @EnvironmentObject var store: Store
    let cls: GymClass

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cls.title).font(.headline).foregroundColor(Palette.text(store.lightMode))
                        if let instr = store.instructor(cls.instructor) {
                            NavigationLink { InstructorProfileView(instructor: instr) } label: {
                                HStack(spacing: 4) {
                                    Text("\(cls.day) · \(cls.time) ·").font(.caption).foregroundColor(Palette.muted(store.lightMode))
                                    Text(instr.name).font(.caption.bold()).foregroundColor(Palette.accent)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    if let studio = store.studio(cls.studioId) {
                        Text("\(studio.credits) cr").font(.caption.bold()).foregroundColor(Palette.accent)
                    }
                }
                let occ = store.occupancy(cls)
                ProgressView(value: Double(occ), total: Double(cls.spots))
                    .tint(occ >= cls.spots ? .red : Palette.accent)
                HStack {
                    Text("\(occ)/\(cls.spots) booked").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                    Spacer()
                    if store.role == .member {
                        Button {
                            store.toggleBooking(cls)
                        } label: {
                            Text(store.isBooked(cls) ? "Booked ✓" : (occ >= cls.spots ? "Full" : "Book"))
                                .font(.caption.bold())
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(store.isBooked(cls) ? Color.green.opacity(0.2) : Palette.accent.opacity(0.18))
                                .foregroundColor(store.isBooked(cls) ? .green : Palette.accent)
                                .clipShape(Capsule())
                        }
                        .disabled(!store.isBooked(cls) && occ >= cls.spots)
                    }
                }
            }
        }
    }
}

// MARK: - Membership
struct MembershipView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "Choose your plan", subtitle: "Credit-based, cancel anytime")
            ForEach(TIERS) { tier in
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tier.name).font(.headline).foregroundColor(Palette.text(store.lightMode))
                            if tier.popular { Pill(text: "Most popular") }
                            Spacer()
                            Text("$\(tier.price)").font(.title3.bold()).foregroundStyle(Palette.brand)
                            Text("/mo").font(.caption).foregroundColor(Palette.muted(store.lightMode))
                        }
                        Text("\(tier.credits) credits/mo · ~\(tier.credits / Model.creditsPerClass) classes")
                            .font(.caption).foregroundColor(Palette.muted(store.lightMode))
                        Button {
                            store.subscribe(tier)
                        } label: {
                            Text(store.tierId == tier.id ? "Current plan ✓" : "Choose \(tier.name)")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(store.tierId == tier.id ? Color.green.opacity(0.2) : Palette.accent.opacity(0.18))
                                .foregroundColor(store.tierId == tier.id ? .green : Palette.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Bookings
struct BookingsView: View {
    @EnvironmentObject var store: Store
    var booked: [GymClass] { store.classes.filter { store.bookings.contains($0.id) } }

    var body: some View {
        VStack(spacing: 12) {
            if booked.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No bookings yet").font(.headline).foregroundColor(Palette.text(store.lightMode))
                        Text("Head to Discover to book your first class.").font(.subheadline).foregroundColor(Palette.muted(store.lightMode))
                    }
                }
            } else {
                SectionTitle(title: "Your classes")
                ForEach(booked) { cls in
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cls.title).font(.headline).foregroundColor(Palette.text(store.lightMode))
                            if let instr = store.instructor(cls.instructor) {
                                NavigationLink { InstructorProfileView(instructor: instr) } label: {
                                    HStack(spacing: 4) {
                                        Text("\(cls.day) · \(cls.time) ·").font(.caption).foregroundColor(Palette.muted(store.lightMode))
                                        Text(instr.name).font(.caption.bold()).foregroundColor(Palette.accent)
                                    }
                                }.buttonStyle(.plain)
                                StarPicker(prompt: "Rate instructor:") { store.rate(instructorId: instr.id, stars: $0) }
                            }
                            Button("Cancel booking") { store.toggleBooking(cls) }
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
}
