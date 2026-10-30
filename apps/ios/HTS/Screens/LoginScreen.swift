import HTSDesign
import SwiftUI

/// The only screen without a session (docs/decisions/0031): 不屈 and the wordmark in the middle, username or e-mail,
/// password and Entrar. No sign-up and no password reset: accounts are created on the server.
struct LoginScreen: View {
    @Environment(AppModel.self) private var app
    @State private var identifier = ""
    @State private var password = ""
    @State private var error: AppModel.SignInError?
    @State private var signingIn = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: HTSSpacing.space7) {
                    Spacer(minLength: HTSSpacing.space8)
                    brand
                    VStack(alignment: .leading, spacing: HTSSpacing.space5) {
                        HTSTextField(
                            label: "USERNAME OU E-MAIL", text: $identifier, contentType: .username
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        HTSTextField(label: "SENHA", text: $password, secure: true, contentType: .password)
                            .onSubmit(submit)
                        HTSButton(signingIn ? "Entrando…" : "Entrar", action: submit)
                            .disabled(!canSubmit)
                            .opacity(canSubmit || signingIn ? 1 : 0.4)
                        if let error {
                            Text(message(for: error)).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                        }
                    }
                    Spacer(minLength: HTSSpacing.space8)
                }
                .padding(.horizontal, HTSSpacing.space5)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.hts.black)
        .preferredColorScheme(.dark)
    }

    private var brand: some View {
        VStack(spacing: HTSSpacing.space3) {
            Text(verbatim: "不屈").htsTextStyle(.kanji).foregroundStyle(Color.hts.tabIdle)
                .accessibilityHidden(true)
            Text(Wordmark.text)
                .htsTextStyle(.brandApp)
                .font(.custom(HTSFontFamily.stencil.postScriptName(weight: 900), size: HTSTextStyle.uiTitle.size))
                .accessibilityLabel("Hard To Submit")
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var canSubmit: Bool {
        !signingIn && !identifier.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        signingIn = true
        error = nil
        Task {
            error = await app.signIn(identifier: identifier, password: password)
            signingIn = false
        }
    }

    private func message(for error: AppModel.SignInError) -> LocalizedStringKey {
        switch error {
        case .invalidCredentials: "Usuário ou senha incorretos."
        case .offline: "Sem conexão. O login precisa de internet."
        case .tooManyAttempts: "Muitas tentativas. Tente de novo em alguns minutos."
        case .other: "Não foi possível entrar. Tente de novo."
        }
    }
}

/// Picks the root: nothing while reading the saved session, the login without one, the tabs with one.
struct AuthGate: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        switch app.authState {
        case .checking: Color.hts.black.ignoresSafeArea()
        case .signedOut: LoginScreen()
        case .signedIn: RootView()
        }
    }
}
