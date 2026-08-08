import SwiftUI

/// Pantalla principal: reactor centrado, transcripción/respuesta, waveform y
/// caption de estado. Tocar el reactor = hablar (o parar).
struct HUDView: View {
    @Environment(AssistantViewModel.self) private var viewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var showConversation = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    ArcReactorView(state: viewModel.state, audioLevel: viewModel.audioLevel)
                        .frame(maxWidth: 280)
                        .glow(Theme.reactorColor(for: viewModel.state), radius: 24)
                        .onTapGesture {
                            viewModel.reactorTapped()
                        }
                        .accessibilityLabel("Reactor. Tocar para hablar con Jarvis.")

                    statusCaption

                    transcriptPanel

                    Spacer()

                    if !viewModel.hasAPIKey {
                        apiKeyBanner
                    }

                    WaveformView(state: viewModel.state, audioLevel: viewModel.audioLevel)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("J.A.R.V.I.S.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showConversation = true
                    } label: {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(Theme.arcBlue)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.arcBlue)
                    }
                }
            }
            .sheet(isPresented: $showConversation) {
                ConversationView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.scenePhaseChanged(to: newPhase)
        }
    }

    private var statusCaption: some View {
        Text(viewModel.state.caption)
            .font(Theme.hudFont(size: 15, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(minHeight: 40)
    }

    @ViewBuilder
    private var transcriptPanel: some View {
        let text = displayText
        if !text.isEmpty {
            Text(text)
                .font(Theme.hudFont(size: 18))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.arcBlue.opacity(0.06))
                        .stroke(Theme.arcBlue.opacity(0.25), lineWidth: 1)
                )
        }
    }

    private var displayText: String {
        switch viewModel.state {
        case .listeningForCommand:
            return viewModel.liveTranscript
        case .speaking, .thinking:
            return viewModel.currentResponse.isEmpty ? viewModel.liveTranscript : viewModel.currentResponse
        default:
            return viewModel.currentResponse
        }
    }

    private var apiKeyBanner: some View {
        Button {
            showSettings = true
        } label: {
            Label("Configura tu clave de API de Anthropic", systemImage: "key.fill")
                .font(Theme.hudFont(size: 14, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(Theme.gold.opacity(0.12))
                        .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                )
        }
    }
}

#Preview {
    HUDView()
        .environment(AssistantViewModel())
}
