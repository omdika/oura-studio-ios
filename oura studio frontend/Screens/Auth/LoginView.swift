import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String? = nil
    @State private var verifiedInvitationToken: String? = nil
    @State private var showingInviteSheet = false
    @State private var oauthCoordinator = GoogleOAuthCoordinator()
    #if DEBUG
    @State private var devToken = ""
    #endif

    var body: some View {
        ZStack {
            OuraTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Brand
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(OuraTheme.Colors.accentGradient)
                            .frame(width: 72, height: 72)
                        Image(systemName: "scissors")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 4) {
                        Text("Oura Studios")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(OuraTheme.Colors.textPrimary)
                            .tracking(-0.3)
                        Text("Manajemen Produksi & Stok")
                            .font(.system(size: 14))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                    }
                }
                .padding(.bottom, 56)

                // Sign in card
                VStack(spacing: 16) {
                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(OuraTheme.Colors.dangerText)
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.dangerText)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OuraTheme.Colors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let success = successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OuraTheme.Colors.accent)
                            Text(success)
                                .font(.system(size: 13))
                                .foregroundStyle(OuraTheme.Colors.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                                .stroke(OuraTheme.Colors.accent.opacity(0.3), lineWidth: 1)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        Task { await performGoogleLogin() }
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(OuraTheme.Colors.textPrimary)
                            } else {
                                GoogleGIcon()
                                    .frame(width: 20, height: 20)
                                Text("Masuk dengan Google")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(OuraTheme.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuraTheme.Radius.medium)
                                .stroke(OuraTheme.Colors.border, lineWidth: 1)
                        )
                    }
                    .disabled(isLoading)

                    Button {
                        showingInviteSheet = true
                    } label: {
                        Text("Punya Kode Undangan?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.accent)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                .animation(.easeInOut(duration: 0.2), value: errorMessage)

                #if DEBUG
                // TODO: Remove when Google Sign-In production OAuth is configured.
                // Dev-only: paste bearer token to authenticate without Google Sign-In.
                VStack(spacing: 10) {
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(OuraTheme.Colors.border)
                        Text("DEV MODE")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textTertiary)
                            .fixedSize()
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(OuraTheme.Colors.border)
                    }
                    .padding(.top, 24)

                    TextField("Paste bearer token...", text: $devToken, axis: .vertical)
                        .lineLimit(3)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(10)
                        .background(OuraTheme.Colors.surfaceSheet)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: OuraTheme.Radius.small)
                                .stroke(OuraTheme.Colors.border, lineWidth: 1)
                        )

                    Button {
                        appState.loginWithDevToken(devToken.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        Text("Masuk Dev")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(devToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? OuraTheme.Colors.textTertiary
                                : OuraTheme.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                    .disabled(devToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, OuraTheme.Spacing.horizontal)
                #endif

                Spacer()
                Spacer()

                Text("v3.48")
                    .font(.system(size: 11))
                    .foregroundStyle(OuraTheme.Colors.textTertiary)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteVerificationSheet(
                isPresented: $showingInviteSheet,
                verifiedToken: $verifiedInvitationToken,
                successMessage: $successMessage,
                errorMessage: $errorMessage
            )
        }
    }

    private func performGoogleLogin() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if APIService.shared.useMock {
                try await appState.loginWithGoogle(idToken: nil, invitationToken: verifiedInvitationToken)
                return
            }
            let idToken = try await oauthCoordinator.requestIDToken()
            try await appState.loginWithGoogle(idToken: idToken, invitationToken: verifiedInvitationToken)
        } catch ASWebAuthenticationSessionError.canceledLogin {
            // user cancelled — no error shown
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Google G icon

private struct GoogleGIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w / 2, cy = h / 2
            let r = min(w, h) / 2

            func arc(from s: Double, to e: Double, color: Color) {
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy))
                path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                            startAngle: .degrees(s), endAngle: .degrees(e), clockwise: false)
                path.closeSubpath()
                ctx.fill(path, with: .color(color))
            }

            let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)
            let red    = Color(red: 0.918, green: 0.263, blue: 0.208)
            let yellow = Color(red: 0.984, green: 0.737, blue: 0.020)
            let green  = Color(red: 0.204, green: 0.659, blue: 0.325)

            arc(from: -90, to: 0,   color: blue)
            arc(from: 0,   to: 90,  color: red)
            arc(from: 90,  to: 180, color: yellow)
            arc(from: 180, to: 270, color: green)

            var inner = Path()
            inner.addEllipse(in: CGRect(x: cx - r*0.55, y: cy - r*0.55, width: r*1.1, height: r*1.1))
            ctx.fill(inner, with: .color(.white))

            var bar = Path()
            bar.addRect(CGRect(x: cx, y: cy - r*0.25, width: r + 4, height: r*0.5))
            ctx.fill(bar, with: .color(.white))

            var tongue = Path()
            tongue.addRect(CGRect(x: cx, y: cy - r*0.25, width: r*0.45, height: r*0.5))
            ctx.fill(tongue, with: .color(blue))
        }
    }
}

// MARK: - Google OAuth coordinator

final class GoogleOAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
    }

    func requestIDToken() async throws -> String {
        // 1. Ambil Google Client ID secara dinamis dari Info.plist, dengan fallback
        let clientID = (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String)
            ?? "763614853578-oura-studio-placeholder.apps.googleusercontent.com"
        
        guard !clientID.isEmpty else {
            throw APIError.serverError(0, "GoogleClientID tidak terkonfigurasi")
        }
        
        // 2. Tentukan Reversed Client ID sebagai Skema URL Callback
        let components = clientID.components(separatedBy: ".")
        let reversedClientID = components.reversed().joined(separator: ".")
        let redirectURI = "\(reversedClientID):/oauth2callback"

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",     value: clientID),
            URLQueryItem(name: "redirect_uri",  value: redirectURI),
            URLQueryItem(name: "response_type", value: "id_token"),
            URLQueryItem(name: "scope",         value: "openid email profile"),
            URLQueryItem(name: "nonce",         value: UUID().uuidString),
        ]
        guard let authURL = comps.url else { throw APIError.invalidURL }

        return try await withCheckedThrowingContinuation { continuation in
            // Menggunakan reversedClientID sebagai skema callback yang diintersep oleh iOS
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: reversedClientID
            ) { callbackURL, error in
                if let error { 
                    continuation.resume(throwing: error)
                    return 
                }
                guard let fragment = callbackURL?.fragment,
                      let idToken = URLComponents(string: "?\(fragment)")?
                          .queryItems?.first(where: { $0.name == "id_token" })?.value
                else {
                    continuation.resume(throwing: APIError.serverError(0, "Token Google tidak ditemukan di URL fragment"))
                    return
                }
                continuation.resume(returning: idToken)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
            self.activeSession = session
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
        .environmentObject(APIService.shared)
}

// MARK: - Invite Verification Sheet

struct InviteVerificationSheet: View {
    @Binding var isPresented: Bool
    @Binding var verifiedToken: String?
    @Binding var successMessage: String?
    @Binding var errorMessage: String?
    
    @State private var email = ""
    @State private var code = ""
    @State private var isLoading = false
    @State private var sheetError: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                OuraTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Verifikasi Kode Undangan")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(OuraTheme.Colors.textPrimary)
                        .padding(.top, 10)
                    
                    Text("Masukkan email Anda dan 6-digit kode undangan yang Anda terima dari Admin.")
                        .font(.system(size: 14))
                        .foregroundStyle(OuraTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if let err = sheetError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(OuraTheme.Colors.dangerText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(OuraTheme.Colors.dangerBg)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.small))
                            .padding(.horizontal, 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Penerima")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        
                        TextField("Email Anda", text: $email)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(OuraTheme.Colors.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: OuraTheme.Radius.small)
                                    .stroke(OuraTheme.Colors.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kode Undangan (6 Karakter)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OuraTheme.Colors.textSecondary)
                        
                        TextField("Contoh: 8X2K9F", text: $code)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .padding()
                            .background(OuraTheme.Colors.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: OuraTheme.Radius.small)
                                    .stroke(OuraTheme.Colors.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button {
                        Task { await performVerification() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Verifikasi Kode")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(email.isEmpty || code.isEmpty ? OuraTheme.Colors.textTertiary : OuraTheme.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
                    }
                    .disabled(isLoading || email.isEmpty || code.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Pendaftaran Anggota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        isPresented = false
                    }
                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                }
            }
        }
    }
    
    private func performVerification() async {
        sheetError = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            let res = try await APIService.shared.verifyInvite(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            )
            verifiedToken = res.invitationToken
            successMessage = "Kode undangan untuk \(email) terverifikasi! Silakan klik 'Masuk dengan Google' dengan akun Google Anda."
            errorMessage = nil
            isPresented = false
        } catch let e as APIError {
            sheetError = e.errorDescription
        } catch {
            sheetError = error.localizedDescription
        }
    }
}
