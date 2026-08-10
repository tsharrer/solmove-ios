import SwiftUI

private let timeFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
}()

// MARK: - Inbox
struct MessagesView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                if store.role == .member {
                    Card { Text("Messaging is for studios and instructors. Switch roles to chat.")
                        .font(.subheadline).foregroundColor(Palette.muted(store.lightMode)) }
                } else if store.myThreads.isEmpty {
                    Card { Text("No conversations yet.").font(.subheadline).foregroundColor(Palette.muted(store.lightMode)) }
                } else {
                    ForEach(store.myThreads) { thread in
                        NavigationLink { ThreadView(thread: thread) } label: { threadRow(thread) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Messages")
    }

    private func threadRow(_ thread: MessageThread) -> some View {
        Card {
            HStack(spacing: 12) {
                Avatar(name: store.counterpartName(for: thread), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.counterpartName(for: thread)).font(.subheadline.bold()).foregroundColor(Palette.text(store.lightMode))
                    if let last = store.lastMessage(in: thread.id) {
                        Text(last.text).font(.caption).foregroundColor(Palette.muted(store.lightMode)).lineLimit(1)
                    }
                }
                Spacer()
                if let last = store.lastMessage(in: thread.id) {
                    Text(timeFmt.string(from: Date(timeIntervalSince1970: last.ts)))
                        .font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                }
            }
        }
    }
}

// MARK: - Conversation
struct ThreadView: View {
    @EnvironmentObject var store: Store
    let thread: MessageThread
    @State private var draft = ""

    var body: some View {
        ZStack {
            Palette.bg(store.lightMode).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.messages(in: thread.id)) { msg in
                                bubble(msg).id(msg.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: store.messages(in: thread.id).count) { _, _ in
                        if let last = store.messages(in: thread.id).last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                composer
            }
        }
        .navigationTitle(store.counterpartName(for: thread))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bubble(_ msg: Message) -> some View {
        let mine = msg.senderRole == store.role
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                Text(msg.text)
                    .font(.subheadline)
                    .foregroundColor(mine ? .white : Palette.text(store.lightMode))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(mine ? AnyShapeStyle(Palette.brand) : AnyShapeStyle(Palette.card(store.lightMode)))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(mine ? Color.clear : Palette.line(store.lightMode), lineWidth: 1))
                Text(timeFmt.string(from: Date(timeIntervalSince1970: msg.ts)))
                    .font(.system(size: 9)).foregroundColor(Palette.muted(store.lightMode))
            }
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Palette.card(store.lightMode))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line(store.lightMode), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Button {
                store.send(threadId: thread.id, text: draft)
                draft = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(Palette.brand)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(Palette.bg(store.lightMode))
    }
}

// A contextual "Message" button that opens (or creates) the thread between a studio & instructor.
struct MessageLink: View {
    @EnvironmentObject var store: Store
    let studioId: String
    let instructorId: String
    var body: some View {
        NavigationLink {
            ThreadView(thread: store.thread(studioId: studioId, instructorId: instructorId))
        } label: {
            Label("Message", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.caption.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Palette.accent.opacity(0.18)).foregroundColor(Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
