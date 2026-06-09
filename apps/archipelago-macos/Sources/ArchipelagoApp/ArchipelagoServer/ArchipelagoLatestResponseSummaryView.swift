import SwiftUI

struct ArchipelagoLatestResponseSummaryView: View {
    let agentType: ArchipelagoAgentType
    let summary: String
    var title = "最后回复"
    var maxLines = 2

    private var tint: Color {
        ArchipelagoDesign.agentColor(agentType)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16, height: 16)
                .background(tint.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                    Text(agentType.shortName)
                        .foregroundStyle(tint)
                }
                .font(ArchipelagoDesign.badgeFont())

                Text(summary)
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkSecondary)
                    .lineLimit(maxLines)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
    }
}
