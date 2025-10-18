//
//  ContentView.swift
//  nova
//
//  Created by Rohith Gandhi  on 10/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()

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
    }

    private var header: some View {
        HStack {
            Label("Nova", systemImage: "sparkles")
                .font(.title3.weight(.semibold))
            Spacer()
            if vm.isStreaming { ProgressView().controlSize(.small) }
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
        HStack(alignment: .center, spacing: 8) {
            ChatInputTextView(text: $vm.input) {
                Task { await vm.send() }
            }
            .frame(minHeight: 24, maxHeight: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.25))
            )
            .disabled(vm.isStreaming)

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
        Text(message.text)
            .textSelection(.enabled)
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
