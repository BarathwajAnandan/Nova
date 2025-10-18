import SwiftUI

struct SparklesIconView: View {
    let onClick: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    @State private var hovering: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThickMaterial)
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
        }
        .frame(width: 44, height: 44)
        .overlay(
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: hovering ? 8 : 4)
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
        .onTapGesture {
            onClick()
        }
    }
}


