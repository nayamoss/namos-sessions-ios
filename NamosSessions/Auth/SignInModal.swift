import ClerkKit
import SwiftUI

/// Clerk's email-code flow, adapted from Sentio's shipping sign-in screen. The view is
/// only constructed after ClerkAuthManager has configured Clerk.shared successfully.
struct SignInModal: View {
    @State private var step: Step = .email
    @State private var email = ""
    @State private var otp = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingSignIn: SignIn?

    private enum Step {
        case email
        case otp
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("NAMOS SESSIONS")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(NamosColor.mutedText)
                Text(step == .email ? "Sign in to your event" : "Check your email")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(NamosColor.text)
                Text(step == .email
                     ? "Use the same account as Namos Sessions on the web."
                     : "Enter the 6-digit code sent to \(email).")
                    .font(.system(size: 15))
                    .foregroundStyle(NamosColor.mutedText)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(step == .email ? "Email" : "Verification code")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NamosColor.text)

                if step == .email {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(NamosColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    actionButton("Continue", enabled: email.isValidEmail, action: requestCode)
                } else {
                    TextField("000000", text: $otp)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .padding(14)
                        .background(NamosColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: otp) { _, value in
                            otp = String(value.filter(\.isNumber).prefix(6))
                        }
                    actionButton("Verify code", enabled: otp.count == 6) {
                        Task { await verifyCode() }
                    }
                    Button("Use a different email") {
                        step = .email
                        otp = ""
                        errorMessage = nil
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(NamosColor.accent)
                }
            }
            .padding(20)
            .background(NamosColor.surface.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(NamosColor.warning)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NamosColor.background)
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .disabled(!enabled || isLoading)
        .foregroundStyle(.white)
        .background(enabled ? NamosColor.accent : NamosColor.mutedText)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func requestCode() {
        guard email.isValidEmail else { return }
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                pendingSignIn = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: email)
                withAnimation(.easeInOut(duration: 0.2)) { step = .otp }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func verifyCode() async {
        guard let pendingSignIn, otp.count == 6 else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await pendingSignIn.verifyCode(otp)
            if result.status == .complete {
                HapticManager.shared.notification(type: .success)
            } else {
                errorMessage = "Verification incomplete. Please try again."
            }
        } catch let clerkError as ClerkAPIError {
            if clerkError.code == "signed_out" {
                self.pendingSignIn = nil
                otp = ""
                step = .email
                errorMessage = "Your sign-in attempt expired. Request a new code."
            } else {
                errorMessage = clerkError.errorDescription ?? "The code could not be verified. Try again."
            }
            HapticManager.shared.notification(type: .error)
        } catch {
            errorMessage = "The code could not be verified. Try again."
            HapticManager.shared.notification(type: .error)
        }
    }
}

private extension String {
    var isValidEmail: Bool {
        range(of: #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }
}
