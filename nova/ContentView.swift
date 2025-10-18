//
//  ContentView.swift
//  nova
//
//  Created by Rohith Gandhi  on 10/18/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            chatList
            Divider()
            inputBar
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(Color(nsColor: .textBackgroundColor))
        // Attach the window accessor invisibly so it doesn't affect layout
        .background(WindowAccessor().frame(width: 0, height: 0))
    }

    private var header: some View {
        HStack {
            Label("Nova", systemImage: "sparkles")
                .font(.title3.weight(.semibold))
            Spacer()
            if let app = vm.recognizedApp {
                HStack(spacing: 6) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Text(app.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 8)
                .help("Frontmost app recognized by Nova")
            }
            Toggle("Auto-capture", isOn: Binding(
                get: { vm.autoCaptureEnabled },
                set: { vm.setAutoCapture($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .help("Continuously capture text from the frontmost window and attach as context (no auto-send)")
            if vm.isStreaming { ProgressView().controlSize(.small) }
            // Button(action: { vm.captureSelection() }) {dd 
            //     Image(systemName: "rectangle.and.text.magnifyingglass")
            // }
            // .buttonStyle(.plain)
            // .help("Capture currently selected text from the frontmost app")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if vm.loadApiKeyExists() == false {
                        EmptyState()
                    }
                    ForEach(vm.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                    if vm.isStreaming { TypingIndicator() }
                    if let err = vm.errorMessage {
                        ErrorBanner(text: err)
                    }
                }
                .padding(16)
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let ctx = vm.pendingContext {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("Context attached (\(ctx.count) chars)\(vm.recognizedApp != nil ? " from \(vm.recognizedApp!.name)" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Button(action: { vm.clearPendingContext() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Remove attached selection context")
                }
                .padding(.horizontal, 4)
            }
            HStack(alignment: .center, spacing: 8) {
            ChatInputTextView(text: $vm.input, isEnabled: !vm.isStreaming) {
                Task { await vm.send() }
            }
            .frame(minHeight: 24, maxHeight: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.25))
            )
            // Do not use SwiftUI .disabled on NSViewRepresentable text view; manage editability internally

            Button(action: { Task { await vm.send() } }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(vm.isStreaming || vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.accentColor))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
            }
        }
        .padding(10)
        .padding(.horizontal, 8)
    }
}

private struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .model {
                avatar
                bubble
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                bubble
                avatar
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatar: some View {
        Circle()
            .fill(message.role == .user ? Color.accentColor : Color.purple.opacity(0.8))
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: message.role == .user ? "person.fill" : "sparkles")
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .semibold))
            )
    }

    private var bubble: some View {
        MarkdownBlockText(markdown: message.text)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(message.role == .user ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
            )
            .frame(maxWidth: 560, alignment: message.role == .user ? .trailing : .leading)
    }
}

private struct TypingIndicator: View {
    @State private var phase: Int = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.0 : 0.6)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

private struct ErrorBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(text)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome to Nova")
                .font(.title3.weight(.semibold))
            Text("Open Settings (⌘,) and add your Gemini API key to start chatting.")
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }
}

#Preview { ContentView() }
