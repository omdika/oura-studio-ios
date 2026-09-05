import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var api: APIService

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String? = nil
    @State private var verifiedInvitationToken: String? = nil
    @State private var showingInviteSheet = false
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

                    Toggle(isOn: Binding(
                        get: { api.useMock },
                        set: { api.useMock = $0 }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(OuraTheme.Colors.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gunakan Mock Data")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(OuraTheme.Colors.textPrimary)
                                Text("Berjalan tanpa koneksi ke server real")
                                    .font(.system(size: 11))
                                    .foregroundStyle(OuraTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .tint(OuraTheme.Colors.accent)
                    .padding(.vertical, 4)

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

                Text("v3.49")
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
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                throw APIError.serverError(0, "Gagal mendapatkan window scene aktif")
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw APIError.serverError(0, "Gagal mengekstrak ID Token dari Google")
            }
            
            try await appState.loginWithGoogle(idToken: idToken, invitationToken: verifiedInvitationToken)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                // GIDSignInErrorCodeCanceled = -5 (User cancelled flow)
                return
            }
            
            if let apiError = error as? APIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
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
