import SwiftUI

struct AuthView: View {
    @EnvironmentObject var store: Store
    @State private var mode: Mode = .login
    @State private var email = "member@solmove.app"
    @State private var password = "solmove123"
    @State private var name = ""
    @State private var role: Role = .member

    enum Mode { case login, register }

    var body: some View {
        ZStack {
            Palette.bg(store.lightMode).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    // Brand mark
                    VStack(spacing: 8) {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Palette.brand)
                        HStack(spacing: 2) {
                            Text("Sol").font(.largeTitle.bold()).foregroundColor(Palette.text(store.lightMode))
                            Text("move").font(.largeTitle.bold()).foregroundStyle(Palette.brand)
                        }
                        Text("One membership. Every studio.")
                            .font(.subheadline).foregroundColor(Palette.muted(store.lightMode))
                    }
                    .padding(.top, 40)

                    // Mode switch
                    Picker("", selection: $mode) {
                        Text("Log in").tag(Mode.login)
                        Text("Sign up").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)

                    Card {
                        VStack(spacing: 14) {
                            if mode == .register {
                                field("Name", text: $name, placeholder: "Alex Rivera")
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("I am a").font(.caption).foregroundColor(Palette.muted(store.lightMode))
                                    Picker("Role", selection: $role) {
                                        ForEach(Role.allCases, id: \.self) { Text($0.label).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            field("Email", text: $email, placeholder: "you@email.com", keyboard: .emailAddress)
                            secureField("Password", text: $password)

                            if let err = store.authError {
                                Text(err).font(.caption).foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: submit) {
                                HStack {
                                    if store.isLoading { ProgressView().tint(.white) }
                                    Text(mode == .login ? "Log in" : "Create account").bold()
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Palette.brand).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(store.isLoading)
                        }
                    }

                    Button("Continue in demo mode") { store.continueOffline() }
                        .font(.subheadline).foregroundColor(Palette.muted(store.lightMode))

                    if mode == .login {
                        Text("Demo: member@solmove.app · studio@solmove.app · maya@solmove.app\nPassword: solmove123")
                            .font(.caption2).multilineTextAlignment(.center)
                            .foregroundColor(Palette.muted(store.lightMode))
                    }
                }
                .padding(20)
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["SOLMOVE_DEMO"] == "1" {
                store.continueOffline()
            }
        }
    }

    private func submit() {
        Task {
            if mode == .login {
                await store.login(email: email, password: password)
            } else {
                await store.register(email: email, password: password, name: name.isEmpty ? "New User" : name, role: role)
            }
        }
    }

    @ViewBuilder private func field(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(Palette.muted(store.lightMode))
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(12)
                .background(Palette.bg(store.lightMode))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(Palette.muted(store.lightMode))
            SecureField("••••••••", text: text)
                .padding(12)
                .background(Palette.bg(store.lightMode))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
