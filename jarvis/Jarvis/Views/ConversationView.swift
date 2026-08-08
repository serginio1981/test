import SwiftUI

/// Historial de la conversación en burbujas: usuario (dorado, derecha) y
/// Jarvis (azul, izquierda).
struct ConversationView: View {
    @Environment(AssistantViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
            .navigationTitle("Conversación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Theme.arcBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearConversation()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44))
                .foregroundStyle(Theme.arcBlue.opacity(0.6))
            Text("Aún no hemos hablado, señor.")
                .font(Theme.hudFont(size: 16))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onAppear {
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(Theme.hudFont(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isUser ? Theme.gold.opacity(0.14) : Theme.arcBlue.opacity(0.10))
                        .stroke(
                            isUser ? Theme.gold.opacity(0.35) : Theme.arcBlue.opacity(0.3),
                            lineWidth: 1
                        )
                )
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    ConversationView()
        .environment(AssistantViewModel())
}
