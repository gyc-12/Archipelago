import SwiftUI

struct ArchipelagoAgentIconView: View {
    let agentType: ArchipelagoAgentType
    var size: CGFloat = 14

    var body: some View {
        agentIcon
            .frame(width: size, height: size)
            .accessibilityLabel(agentType.displayName)
    }

    @ViewBuilder
    private var agentIcon: some View {
        switch agentType {
        case .claudeCode:
            ClaudeCodeAgentGlyph()
        case .codex:
            CodexAgentGlyph()
        case .gemini:
            GeminiAgentGlyph()
        case .openCode:
            OpenCodeAgentGlyph()
        case .openClaw:
            OpenClawAgentGlyph()
        case .cline:
            ClineAgentGlyph()
        case .unknown:
            Circle()
                .fill(ArchipelagoDesign.agentColor(.unknown))
        }
    }
}

private struct ClaudeCodeAgentGlyph: View {
    private let tint = ArchipelagoDesign.agentColor(.claudeCode)

    var body: some View {
        GeometryReader { proxy in
            let frame = iconFrame(in: proxy.size)
            ZStack {
                ClaudeCodeBodyShape()
                    .fill(tint)
                ClaudeCodeEyeShape()
                    .fill(Color.black.opacity(0.68))
            }
            .frame(width: frame.length, height: frame.length)
            .position(x: frame.midX, y: frame.midY)
        }
    }
}

private struct CodexAgentGlyph: View {
    var body: some View {
        CodexAgentShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0xb1 / 255.0, green: 0xa7 / 255.0, blue: 0xff / 255.0),
                        Color(red: 0x7a / 255.0, green: 0x9d / 255.0, blue: 0xff / 255.0),
                        Color(red: 0x39 / 255.0, green: 0x41 / 255.0, blue: 0xff / 255.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: FillStyle(eoFill: true)
            )
    }
}

private struct CodexAgentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 20

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.midX + (x - 12) * scale,
                y: rect.midY + (y - 12) * scale
            )
        }

        path.move(to: point(9.064, 3.344))
        path.addCurve(to: point(11.349, 3.032), control1: point(9.787, 3.047), control2: point(10.573, 2.939))
        path.addCurve(to: point(14.022, 4.307), control1: point(12.349, 3.147), control2: point(13.240, 3.572))
        path.addCurve(to: point(14.059, 4.328), control1: point(14.032, 4.317), control2: point(14.046, 4.324))
        path.addCurve(to: point(14.102, 4.328), control1: point(14.073, 4.331), control2: point(14.088, 4.331))
        path.addCurve(to: point(17.148, 4.603), control1: point(15.119, 4.065), control2: point(16.195, 4.163))
        path.addLine(to: point(17.195, 4.625))
        path.addLine(to: point(17.311, 4.682))
        path.addCurve(to: point(19.499, 7.081), control1: point(18.309, 5.188), control2: point(19.087, 6.041))
        path.addCurve(to: point(19.814, 8.676), control1: point(19.708, 7.591), control2: point(19.812, 8.122))
        path.addCurve(to: point(19.680, 9.899), control1: point(19.829, 9.088), control2: point(19.784, 9.500))
        path.addCurve(to: point(19.710, 10.014), control1: point(19.670, 9.940), control2: point(19.681, 9.983))
        path.addCurve(to: point(20.893, 12.184), control1: point(20.304, 10.621), control2: point(20.698, 11.344))
        path.addCurve(to: point(20.006, 16.038), control1: point(21.182, 13.609), control2: point(20.886, 14.894))
        path.addLine(to: point(19.870, 16.204))
        path.addCurve(to: point(17.669, 17.592), control1: point(19.287, 16.871), control2: point(18.522, 17.354))
        path.addCurve(to: point(17.588, 17.668), control1: point(17.631, 17.603), control2: point(17.601, 17.631))
        path.addCurve(to: point(16.848, 19.162), control1: point(17.397, 18.219), control2: point(17.205, 18.691))
        path.addCurve(to: point(13.137, 21.000), control1: point(15.948, 20.349), control2: point(14.626, 21.008))
        path.addCurve(to: point(9.980, 19.698), control1: point(11.950, 20.994), control2: point(10.898, 20.560))
        path.addCurve(to: point(9.875, 19.674), control1: point(9.952, 19.672), control2: point(9.912, 19.663))
        path.addCurve(to: point(8.671, 19.812), control1: point(9.487, 19.799), control2: point(9.095, 19.817))
        path.addCurve(to: point(6.726, 19.346), control1: point(7.996, 19.807), control2: point(7.330, 19.647))
        path.addCurve(to: point(5.116, 18.011), control1: point(6.093, 19.032), control2: point(5.542, 18.575))
        path.addCurve(to: point(4.702, 17.394), control1: point(4.964, 17.809), control2: point(4.813, 17.619))
        path.addCurve(to: point(4.332, 16.433), control1: point(4.550, 17.085), control2: point(4.427, 16.764))
        path.addCurve(to: point(4.318, 14.135), control1: point(4.132, 15.681), control2: point(4.127, 14.890))
        path.addCurve(to: point(4.324, 14.079), control1: point(4.324, 14.117), control2: point(4.326, 14.098))
        path.addCurve(to: point(4.297, 14.031), control1: point(4.321, 14.060), control2: point(4.311, 14.044))
        path.addCurve(to: point(3.263, 12.380), control1: point(3.835, 13.563), control2: point(3.482, 13.000))
        path.addCurve(to: point(3.012, 11.188), control1: point(3.117, 11.998), control2: point(3.033, 11.596))
        path.addCurve(to: point(3.153, 9.588), control1: point(2.976, 10.651), control2: point(3.023, 10.111))
        path.addCurve(to: point(5.086, 6.970), control1: point(3.490, 8.476), control2: point(4.135, 7.603))
        path.addCurve(to: point(5.687, 6.640), control1: point(5.298, 6.829), control2: point(5.499, 6.719))
        path.addCurve(to: point(6.333, 6.413), control1: point(5.902, 6.551), control2: point(6.117, 6.476))
        path.addCurve(to: point(6.398, 6.347), control1: point(6.364, 6.403), control2: point(6.389, 6.378))
        path.addCurve(to: point(7.227, 4.732), control1: point(6.562, 5.758), control2: point(6.844, 5.209))
        path.addCurve(to: point(9.064, 3.344), control1: point(7.710, 4.119), control2: point(8.342, 3.641))
        path.closeSubpath()

        path.move(to: point(12.546, 13.909))
        path.addCurve(to: point(11.945, 14.545), control1: point(12.209, 13.928), control2: point(11.945, 14.207))
        path.addCurve(to: point(12.546, 15.181), control1: point(11.945, 14.883), control2: point(12.209, 15.162))
        path.addLine(to: point(16.182, 15.181))
        path.addCurve(to: point(16.763, 14.874), control1: point(16.418, 15.194), control2: point(16.641, 15.076))
        path.addCurve(to: point(16.763, 14.216), control1: point(16.885, 14.672), control2: point(16.885, 14.418))
        path.addCurve(to: point(16.182, 13.909), control1: point(16.641, 14.014), control2: point(16.418, 13.896))
        path.addLine(to: point(12.546, 13.909))
        path.closeSubpath()

        path.move(to: point(8.462, 9.230))
        path.addCurve(to: point(7.603, 9.010), control1: point(8.282, 8.937), control2: point(7.902, 8.840))
        path.addCurve(to: point(7.356, 9.861), control1: point(7.305, 9.180), control2: point(7.195, 9.557))
        path.addLine(to: point(8.628, 12.085))
        path.addLine(to: point(7.362, 14.221))
        path.addCurve(to: point(7.355, 14.857), control1: point(7.246, 14.417), control2: point(7.243, 14.659))
        path.addCurve(to: point(7.902, 15.182), control1: point(7.466, 15.056), control2: point(7.675, 15.179))
        path.addCurve(to: point(8.457, 14.870), control1: point(8.130, 15.184), control2: point(8.341, 15.066))
        path.addLine(to: point(9.911, 12.415))
        path.addCurve(to: point(9.916, 11.775), control1: point(10.028, 12.218), control2: point(10.030, 11.974))
        path.addLine(to: point(8.462, 9.230))
        path.closeSubpath()

        return path
    }
}

private struct GeminiAgentGlyph: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0xee / 255.0, green: 0x4d / 255.0, blue: 0x5d / 255.0),
                        Color(red: 0xb3 / 255.0, green: 0x81 / 255.0, blue: 0xdd / 255.0),
                        Color(red: 0x20 / 255.0, green: 0x7c / 255.0, blue: 0xfe / 255.0)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .overlay {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Color(red: 0x1e / 255.0, green: 0x1e / 255.0, blue: 0x2e / 255.0))
            }
    }
}

private struct OpenCodeAgentGlyph: View {
    var body: some View {
        Rectangle()
            .strokeBorder(ArchipelagoDesign.onDarkSecondary, lineWidth: 2)
            .padding(2)
    }
}

private struct OpenClawAgentGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0xff / 255.0, green: 0x4d / 255.0, blue: 0x4d / 255.0),
                            Color(red: 0x99 / 255.0, green: 0x1b / 255.0, blue: 0x1b / 255.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            HStack(spacing: 3) {
                Circle().fill(Color.black.opacity(0.72))
                Circle().fill(Color.black.opacity(0.72))
            }
            .frame(width: 9, height: 4)
        }
    }
}

private struct ClineAgentGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.gray.opacity(0.75))
            HStack(spacing: 3) {
                Capsule().fill(Color.black.opacity(0.62))
                Capsule().fill(Color.black.opacity(0.62))
            }
            .frame(width: 10, height: 6)
        }
    }
}

private struct ClaudeCodeBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height) / 24
        let dx = rect.midX - 12 * s
        let dy = rect.midY - 12 * s

        func scaled(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: dx + x * s, y: dy + y * s, width: width * s, height: height * s)
        }

        path.addRoundedRect(in: scaled(3, 5, 18, 12.1), cornerSize: CGSize(width: 1.8 * s, height: 1.8 * s))
        path.addRect(scaled(0, 10.95, 3.2, 3.1))
        path.addRect(scaled(20.8, 10.95, 3.2, 3.1))
        path.addRect(scaled(4.5, 16.5, 1.5, 3.5))
        path.addRect(scaled(7.5, 16.5, 1.5, 3.5))
        path.addRect(scaled(15, 16.5, 1.5, 3.5))
        path.addRect(scaled(18, 16.5, 1.5, 3.5))

        return path
    }
}

private struct ClaudeCodeEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height) / 24
        let dx = rect.midX - 12 * s
        let dy = rect.midY - 12 * s

        func scaled(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: dx + x * s, y: dy + y * s, width: width * s, height: height * s)
        }

        path.addRoundedRect(in: scaled(6, 8.1, 1.6, 2.9), cornerSize: CGSize(width: 0.4 * s, height: 0.4 * s))
        path.addRoundedRect(in: scaled(16.4, 8.1, 1.6, 2.9), cornerSize: CGSize(width: 0.4 * s, height: 0.4 * s))

        return path
    }
}

private struct IconFrame {
    let midX: CGFloat
    let midY: CGFloat
    let length: CGFloat
}

private func iconFrame(in size: CGSize) -> IconFrame {
    let length = min(size.width, size.height)
    return IconFrame(midX: size.width / 2, midY: size.height / 2, length: length)
}
