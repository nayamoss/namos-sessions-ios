import Combine
import ElevenLabs
import SwiftUI

/// A focused, hands-free conversation mode backed by ElevenLabs Conversational AI.
struct VoiceConversationView: View {
    private enum SessionPhase {
        case connecting
        case unavailable(String)
        case error(String)
        case connected(Conversation)
    }

    let eventId: ConvexId

    @Environment(\.dismiss) private var dismiss
    @State private var phase: SessionPhase = .connecting
    @State private var hasStarted = false
    @State private var hasEndedSession = false

    var body: some View {
        Group {
            switch phase {
            case .unavailable(let reason):
                Text(reason)
                    .font(.system(size: 17))
                    .foregroundStyle(NamosColor.text)
                    .multilineTextAlignment(.center)
                    .padding(32)

            case .connecting:
                VoiceStatusView(label: "Connecting…", isAnimating: true)

            case .error(let message):
                VStack(spacing: 18) {
                    VoiceStatusView(label: "Connection issue", isAnimating: false)
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.warning)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await startSession() }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(NamosColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(32)

            case .connected(let conversation):
                ActiveVoiceConversationView(conversation: conversation, eventId: eventId) {
                    await endSession(conversation, dismissAfterEnding: true)
                } onConnectionIssue: { message in
                    phase = .error(message)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NamosColor.background)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await startSession()
        }
        .onDisappear {
            guard case .connected(let conversation) = phase, !hasEndedSession else { return }
            Task { await endSession(conversation, dismissAfterEnding: false) }
        }
    }

    private func startSession() async {
        hasEndedSession = false
        phase = .connecting

        do {
            let store = VoiceSessionStore()
            let availability = try await store.availability(for: eventId)
            guard availability.available else {
                phase = .unavailable(availability.reason ?? "Voice chat is not configured for this deployment.")
                return
            }

            let response = try await store.createSession(for: eventId)
            guard response.unavailable != true else {
                phase = .unavailable(response.reason ?? "Voice chat is not configured for this deployment.")
                return
            }
            // See VoiceSessionStore for why voice mode needs the token rather than the
            // signed URL. An older backend that predates the token will omit it; say so
            // plainly instead of failing with the SDK's text-only error message.
            guard let conversationToken = response.conversationToken, !conversationToken.isEmpty else {
                phase = .unavailable("This deployment's backend is out of date — it did not return a voice conversation token. Deploy the current Convex functions and try again.")
                return
            }

            let config = ConversationConfig(onError: { error in
                print("[VoiceConversationView] ElevenLabs SDK callback error: \(String(reflecting: error)); localizedDescription=\(error.localizedDescription)")
            })
            let conversation = try await ElevenLabs.startConversation(conversationToken: conversationToken, config: config)
            phase = .connected(conversation)
        } catch is CancellationError {
            return
        } catch {
            logConnectionError(error)
            phase = .error(error.localizedDescription)
        }
    }

    private func logConnectionError(_ error: Error) {
        let nsError = error as NSError
        print("[VoiceConversationView] ElevenLabs connection failed: \(String(reflecting: error)); localizedDescription=\(error.localizedDescription); domain=\(nsError.domain); code=\(nsError.code); userInfo=\(nsError.userInfo)")
    }

    private func endSession(_ conversation: Conversation, dismissAfterEnding: Bool) async {
        hasEndedSession = true
        await conversation.endConversation()
        if dismissAfterEnding {
            dismiss()
        }
    }
}

private struct ActiveVoiceConversationView: View {
    @ObservedObject var conversation: Conversation
    let eventId: ConvexId
    @EnvironmentObject private var navigation: AppNavigationState
    let onEnd: () async -> Void
    let onConnectionIssue: (String) -> Void

    @State private var transcriptExpanded = false
    @State private var isPulsing = false
    @State private var handledToolCallIds = Set<String>()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: conversation.agentState == .speaking ? "waveform" : "waveform.circle.fill")
                    .font(.system(size: 74, weight: .medium))
                    .foregroundStyle(NamosColor.accent)
                    .scaleEffect(isPulsing ? 1.08 : 0.94)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                Text(statusLabel)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(NamosColor.text)
            }

            transcript
                .padding(.top, 34)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    Task {
                        do {
                            try await conversation.toggleMute()
                        } catch {
                            onConnectionIssue(error.localizedDescription)
                        }
                    }
                } label: {
                    Label(conversation.isMuted ? "Unmute" : "Mute", systemImage: conversation.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .foregroundStyle(.white)
                .background(NamosColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    Task { await onEnd() }
                } label: {
                    Label("End session", systemImage: "phone.down.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .foregroundStyle(.white)
                .background(NamosColor.warning)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
        .onChange(of: conversation.state) { _, state in
            if case .error(let error) = state {
                print("[ActiveVoiceConversationView] ElevenLabs state error: \(String(reflecting: error)); localizedDescription=\(error.localizedDescription)")
                onConnectionIssue(error.localizedDescription)
            } else if case .ended = state {
                onConnectionIssue("The voice session ended unexpectedly.")
            }
        }
        .onReceive(conversation.$pendingToolCalls) { toolCalls in
            for toolCall in toolCalls where handledToolCallIds.insert(toolCall.toolCallId).inserted {
                Task { await handle(toolCall) }
            }
        }
    }

    private var statusLabel: String {
        switch conversation.state {
        case .connecting, .idle:
            "Connecting…"
        case .active:
            switch conversation.agentState {
            case .listening: "Listening"
            case .speaking: "Agent is speaking"
            case .thinking: "Thinking…"
            }
        case .ended, .error:
            "Connection issue"
        }
    }

    private var transcript: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    transcriptExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Transcript")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: transcriptExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(NamosColor.mutedText)
                .padding(14)
                .background(NamosColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if transcriptExpanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if conversation.messages.isEmpty {
                            Text("Your conversation will appear here.")
                                .font(.system(size: 14))
                                .foregroundStyle(NamosColor.mutedText)
                        }
                        ForEach(conversation.messages) { message in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(roleLabel(for: message.role))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NamosColor.mutedText)
                                Text(message.content)
                                    .font(.system(size: 14))
                                    .foregroundStyle(NamosColor.text)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(NamosColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func roleLabel(for role: Message.Role) -> String {
        switch role {
        case .user: "You"
        case .agent: "Agent"
        }
    }

    private func handle(_ toolCall: ClientToolCallEvent) async {
        let handler = VoiceAgentToolHandler(eventId: eventId, navigation: navigation)
        let result = await handler.execute(toolCall)
        do {
            try await conversation.sendToolResult(
                for: toolCall.toolCallId,
                result: result.text,
                isError: result.isError
            )
        } catch {
            onConnectionIssue(error.localizedDescription)
        }
    }
}

private struct VoiceStatusView: View {
    let label: String
    let isAnimating: Bool
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(NamosColor.accent)
                .scaleEffect(isPulsing ? 1.08 : 0.94)
                .onAppear {
                    guard isAnimating else { return }
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            Text(label)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(NamosColor.text)
        }
    }
}
