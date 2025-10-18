import SwiftUI

struct SparklesIconView: View {
    let onClick: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    @State private var hovering: Bool = false
    @EnvironmentObject private var vm: ChatViewModel

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThickMaterial)
            Image(systemName: vm.isListening ? "mic.fill" : "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(vm.isListening ? Color.red : Color.primary)
        }
        .frame(width: 44, height: 44)
        .overlay(
            Circle()
                .stroke(vm.isListening ? Color.red.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: hovering ? 8 : 4)
        .animation(.easeInOut(duration: 0.2), value: vm.isListening)
        .onHover { isHovering in
            hovering = isHovering
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    onDragChanged(value.translation)
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
        .onTapGesture(count: 1) { onClick() }
        .onLongPressGesture(minimumDuration: 0.35) { vm.toggleMic() }
    }
}


