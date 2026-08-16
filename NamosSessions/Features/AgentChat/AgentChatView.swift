import SwiftUI

/// Voice-first: hold the mic button, speak the objective, release to send. Typing is
/// the fallback, not the primary path — this is "manage the event from the hallway
/// between sessions," not "sit down and type a paragraph."
struct AgentChatView: View {
    @StateObject private var viewModel: AgentChatViewModel
    @StateObject private var voice = VoiceCaptureService()
    @State private var draftText = ""
    @State private var showTypedInput = false
    @State private var showVoiceConversation = false
    private let eventId: ConvexId

    init(eventId: ConvexId) {
        self.eventId = eventId
        _viewModel = StateObject(wrappedValue: AgentChatViewModel(eventId: eventId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if viewModel.events.isEmpty {
                            EmptyStateView()
                                .padding(.top, 60)
                        }
                        ForEach(viewModel.events) { event in
                            AgentEventBubble(event: event)
                                .id(event.id)
                        }
                        if viewModel.run?.status == "needs_approval" {
                            ForEach(viewModel.proposals.filter { $0.status == "pending" }) { proposal in
                                ProposalCard(proposal: proposal) { approve in
                                    Task { await viewModel.decide(on: proposal, approve: approve) }
                                }
                            }
                        }
                        if let run = viewModel.run, run.status == "running" || run.status == "queued" {
                            ThinkingIndicator()
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.events.count) { _, _ in
                    if let last = viewModel.events.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(NamosColor.warning)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            inputBar
        }
        .background(NamosColor.background)
        .navigationTitle(viewModel.run?.isWaitingForReply == true ? "Waiting for you" : "Agent")
        .task { _ = await voice.requestPermissions() }
        .sheet(isPresented: $showVoiceConversation) {
            VoiceConversationView(eventId: eventId)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 10) {
            if showTypedInput {
                HStack(spacing: 8) {
                    TextField("Tell the agent what to do…", text: $draftText, axis: .vertical)
                        .padding(12)
                        .background(NamosColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("Send") { Task { await sendDraft() } }
                        .disabled(draftText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
                }
            }

            HStack(spacing: 16) {
                Button {
                    showTypedInput.toggle()
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18))
                        .foregroundStyle(NamosColor.mutedText)
                }

                MicButton(isRecording: voice.isRecording) {
                    startTalking()
                } onRelease: {
                    finishTalking()
                }

                Button {
                    showVoiceConversation = true
                } label: {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(NamosColor.accent)
                }
                .accessibilityLabel("Start voice conversation")
            }
        }
        .padding(16)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(16)
    }

    private func startTalking() {
        do { try voice.startRecording() } catch { voice.authorizationError = error.localizedDescription }
    }

    private func finishTalking() {
        voice.stopRecording()
        let transcript = voice.transcript
        guard !transcript.isEmpty else { return }
        Task { await viewModel.send(transcript) }
    }

    private func sendDraft() async {
        let text = draftText
        draftText = ""
        showTypedInput = false
        await viewModel.send(text)
    }
}

private struct ProposalCard: View {
    let proposal: TaskProposal
    let onDecision: (Bool) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Approval needed").font(.system(size: 15, weight: .semibold))
            Text(proposal.summary).font(.system(size: 14)).foregroundStyle(NamosColor.mutedText)
            ForEach(proposal.tasks, id: \.title) { task in
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 14, weight: .medium))
                    Text(task.reason).font(.system(size: 12)).foregroundStyle(NamosColor.mutedText)
                }
            }
            HStack {
                Button("Reject") { onDecision(false) }.foregroundStyle(NamosColor.warning)
                Spacer()
                Button("Approve") { onDecision(true) }.buttonStyle(.borderedProminent).tint(NamosColor.accent)
            }
        }
        .padding(14).background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MicButton: View {
    let isRecording: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        Circle()
            .fill(isRecording ? NamosColor.accent : NamosColor.accent.opacity(0.85))
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .scaleEffect(isRecording ? 1.08 : 1.0)
            .animation(.spring(response: 0.25), value: isRecording)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isRecording { onPress() } }
                    .onEnded { _ in onRelease() }
            )
            // A bare Circle with a DragGesture is invisible to XCUITest unless it is
            // explicitly published as an element. NamosSessionsUITests presses this
            // repeatedly to prove the mic-button crash stays fixed.
            .accessibilityElement()
            .accessibilityIdentifier("agent.micButton")
            .accessibilityLabel("Hold to talk")
    }
}

private struct AgentEventBubble: View {
    let event: AgentRunEvent

    var body: some View {
        HStack {
            if event.isFromUser { Spacer(minLength: 40) }
            Text(event.message)
                .font(.system(size: 15))
                .foregroundStyle(event.isFromUser ? .white : NamosColor.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(event.isFromUser ? NamosColor.accent : NamosColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !event.isFromUser { Spacer(minLength: 40) }
        }
    }
}

private struct ThinkingIndicator: View {
    var body: some View {
        HStack {
            ProgressView().controlSize(.small)
            Text("Working on it…").font(.system(size: 13)).foregroundStyle(NamosColor.mutedText)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle").font(.system(size: 36)).foregroundStyle(NamosColor.mutedText)
            Text("Hold the mic and tell the agent what you need.").font(.system(size: 14)).foregroundStyle(NamosColor.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}
