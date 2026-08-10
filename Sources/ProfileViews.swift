import SwiftUI

// Reusable star input that fires once.
struct StarPicker: View {
    @EnvironmentObject var store: Store
    let prompt: String
    let onRate: (Int) -> Void
    @State private var done = false
    var body: some View {
        HStack(spacing: 6) {
            Text(done ? "Thanks for rating!" : prompt)
                .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
            if !done {
                ForEach(1...5, id: \.self) { s in
                    Button { onRate(s); done = true } label: {
                        Image(systemName: "star").font(.subheadline).foregroundColor(.yellow)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

// Small labeled stat block.
struct MiniStat: View {
    @EnvironmentObject var store: Store
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundColor(Palette.text(store.lightMode))
            Text(label).font(.caption2).foregroundColor(Palette.muted(store.lightMode))
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Instructor profile
struct InstructorProfileView: View {   // pushed / tab wrapper handled by caller
    let instructor: Instructor
    var body: some View { InstructorProfileContent(instructor: instructor) }
}

struct InstructorProfileContent: View {
    @EnvironmentObject var store: Store
    let instructor: Instructor
    var body: some View {
        // Re-fetch live copy so ratings/shifts update the view.
        let instr = store.instructor(instructor.id) ?? instructor
        let venues = store.studiosTeaching(instr.id)
        VStack(spacing: 14) {
            Card {
                HStack(spacing: 14) {
                    Avatar(name: instr.name, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(instr.name).font(.title3.bold()).foregroundColor(Palette.text(store.lightMode))
                        Text(instr.disciplines.joined(separator: " · ")).font(.caption).foregroundColor(Palette.muted(store.lightMode))
                        HStack(spacing: 6) {
                            Pill(text: "⭐ \(store.scoreText(instr))")
                            Pill(text: "Rank #\(store.rank(instr))")
                            Pill(text: "❤️ \(store.followers(instructor: instr))")
                        }
                    }
                    Spacer()
                    if store.role == .member {
                        HeartButton(isOn: store.isFavInstructor(instr.id)) { store.toggleFavInstructor(instr.id) }
                    }
                }
            }

            Card { LevelBar(instructor: instr) }

            Card {
                HStack {
                    MiniStat(value: "\(instr.shiftsCovered)", label: "Shifts covered")
                    Divider().frame(height: 30).background(Palette.line(store.lightMode))
                    MiniStat(value: "\(venues.count)", label: "Studios")
                    Divider().frame(height: 30).background(Palette.line(store.lightMode))
                    MiniStat(value: money(Model.avgShiftPay), label: "Per shift")
                }
            }

            if !instr.badges.isEmpty {
                SectionTitle(title: "Reputation")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(instr.badges, id: \.self) { b in
                            if let badge = INSTRUCTOR_BADGES[b] { Pill(text: "\(badge.icon) \(badge.label)") }
                        }
                    }
                }
            }

            SectionTitle(title: "Achievements", subtitle: "Earn XP by covering shifts & delighting members")
            AchievementGrid(items: store.instructorAchievements(instr))

            SectionTitle(title: "Teaches at", subtitle: "\(venues.count) studios across Houston")
            ForEach(venues) { studio in
                NavigationLink { StudioDetailView(studio: studio) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        StudioCard(studio: studio)
                        let taught = store.classes(for: studio.id).filter { $0.instructor == instr.id }
                        if !taught.isEmpty {
                            Text("Classes: " + taught.map { $0.title }.joined(separator: ", "))
                                .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                                .padding(.horizontal, 4)
                        }
                    }
                }.buttonStyle(.plain)
            }

            if store.role == .member {
                Card { StarPicker(prompt: "Rate \(instr.name):") { store.rate(instructorId: instr.id, stars: $0) } }
            }
        }
    }
}

// MARK: - Studio profile (content shared by detail push + owner tab)
struct StudioProfileContent: View {
    @EnvironmentObject var store: Store
    let studio: Studio
    var isOwner: Bool = false
    var body: some View {
        let s = store.studio(studio.id) ?? studio
        let roster = store.instructorsTeaching(at: s.id)
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.title3.bold()).foregroundColor(Palette.text(store.lightMode))
                            Text(s.neighborhood).font(.caption).foregroundColor(Palette.muted(store.lightMode))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Stars(value: store.studioScore(s))
                            Text(store.studioScoreText(s)).font(.caption).foregroundColor(Palette.muted(store.lightMode))
                        }
                    }
                    HStack {
                        Pill(text: "❤️ \(store.followers(studio: s)) followers")
                        Spacer()
                        if store.role == .member {
                            HeartButton(isOn: store.isFavStudio(s.id)) { store.toggleFavStudio(s.id) }
                        }
                    }
                    if !s.badges.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(s.badges, id: \.self) { b in
                                if let badge = STUDIO_BADGES[b] { Pill(text: "\(badge.icon) \(badge.label)") }
                            } }
                        }
                    }
                }
            }

            SectionTitle(title: "Achievements")
            AchievementGrid(items: store.studioAchievements(s))

            SectionTitle(title: "Instructors here", subtitle: "\(roster.count) teaching this studio")
            ForEach(roster) { instr in
                NavigationLink { InstructorProfileView(instructor: instr) } label: {
                    Card {
                        HStack {
                            Avatar(name: instr.name, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(instr.name).font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                                Text("Lvl \(store.instructorLevel(instr)) · \(store.levelTitle(instr)) · \(store.studiosTeaching(instr.id).count) studios")
                                    .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                            }
                            Spacer()
                            Text("⭐ \(store.scoreText(instr))").font(.caption.bold()).foregroundColor(Palette.text(store.lightMode))
                        }
                    }
                }.buttonStyle(.plain)
            }

            SectionTitle(title: "Schedule")
            ForEach(store.classes(for: s.id)) { cls in ClassRow(cls: cls) }

            if store.role == .member {
                Card { StarPicker(prompt: "Rate \(s.name):") { store.rateStudio(studioId: s.id, stars: $0) } }
            }
        }
    }
}

// MARK: - Member profile
struct MemberProfileContent: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: 14) {
            Card {
                HStack(spacing: 14) {
                    Avatar(name: "You Member", size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your profile").font(.title3.bold()).foregroundColor(Palette.text(store.lightMode))
                        if let tier = store.currentTier {
                            Pill(text: "\(tier.name) · \(tier.credits) cr/mo")
                        } else {
                            Pill(text: "No plan yet")
                        }
                    }
                    Spacer()
                }
            }

            Card {
                HStack {
                    MiniStat(value: "\(store.bookings.count)", label: "Classes")
                    Divider().frame(height: 30).background(Palette.line(store.lightMode))
                    MiniStat(value: "\(store.myStudios.count)", label: "Studios")
                    Divider().frame(height: 30).background(Palette.line(store.lightMode))
                    MiniStat(value: "\(store.myInstructors.count)", label: "Instructors")
                }
            }

            SectionTitle(title: "Achievements")
            AchievementGrid(items: store.memberAchievements())

            if store.currentTier == nil {
                NavigationLink { ThemedScreen { MembershipView() }.navigationTitle("Membership") } label: {
                    Card {
                        HStack {
                            Text("Choose a membership plan").font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                            Spacer(); Image(systemName: "chevron.right").foregroundColor(Palette.accent)
                        }
                    }
                }.buttonStyle(.plain)
            } else {
                NavigationLink { ThemedScreen { MembershipView() }.navigationTitle("Membership") } label: {
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manage membership").font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                                if let t = store.currentTier {
                                    Text("\(t.name) · $\(t.price)/mo · \(t.credits) credits").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                                }
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundColor(Palette.accent)
                        }
                    }
                }.buttonStyle(.plain)
            }

            if !store.favoriteStudios.isEmpty || !store.favoriteInstructors.isEmpty {
                SectionTitle(title: "Favorites", subtitle: "Studios & instructors you follow")
                ForEach(store.favoriteStudios) { studio in
                    NavigationLink { StudioDetailView(studio: studio) } label: { StudioCard(studio: studio) }
                        .buttonStyle(.plain)
                }
                ForEach(store.favoriteInstructors) { instr in
                    NavigationLink { InstructorProfileView(instructor: instr) } label: {
                        Card {
                            HStack {
                                Avatar(name: instr.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instr.name).font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                                    Text("❤️ \(store.followers(instructor: instr)) followers · ⭐ \(store.scoreText(instr))")
                                        .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                                }
                                Spacer(); Image(systemName: "heart.fill").foregroundStyle(Palette.brand)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }

            SectionTitle(title: "Your instructors", subtitle: "See everywhere they teach")
            if store.myInstructors.isEmpty {
                Card { Text("Book a class to start following instructors.").font(.subheadline).foregroundColor(Palette.muted(store.lightMode)) }
            } else {
                ForEach(store.myInstructors) { instr in
                    NavigationLink { InstructorProfileView(instructor: instr) } label: {
                        Card {
                            HStack {
                                Avatar(name: instr.name, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instr.name).font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                                    Text("Teaches at \(store.studiosTeaching(instr.id).count) studios · ⭐ \(store.scoreText(instr))")
                                        .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundColor(Palette.accent)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }

            SectionTitle(title: "Your studios")
            if store.myStudios.isEmpty {
                Card { Text("No studios visited yet.").font(.subheadline).foregroundColor(Palette.muted(store.lightMode)) }
            } else {
                ForEach(store.myStudios) { studio in
                    NavigationLink { StudioDetailView(studio: studio) } label: { StudioCard(studio: studio) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Profile tab router (persona-aware)
struct ProfileTab: View {
    @EnvironmentObject var store: Store
    var body: some View {
        switch store.role {
        case .member:
            MemberProfileContent()
        case .studio:
            if let s = store.managedStudio { StudioProfileContent(studio: s, isOwner: true) }
            else { Text("No studio").foregroundColor(Palette.muted(store.lightMode)) }
        case .instructor:
            if let me = store.me { InstructorProfileContent(instructor: me) }
            else { Text("No profile").foregroundColor(Palette.muted(store.lightMode)) }
        }
    }
}
