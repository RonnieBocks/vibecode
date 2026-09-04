import SwiftUI

/// Post-match notes: quick tags plus free text. Used on the draft summary and
/// again in the match review, where it can be edited later.
struct MatchNotesEditor: View {
    @Binding var notes: String
    @Binding var tags: Set<MatchNoteTag>
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Match notes", systemImage: "square.and.pencil").font(.headline)
                Spacer()
                Text("optional — reviewed later to tune the model")
                    .font(.caption).foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 6) {
                ForEach(MatchNoteTag.allCases) { tag in
                    let on = tags.contains(tag)
                    Button {
                        if on { tags.remove(tag) } else { tags.insert(tag) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tag.symbol).font(.caption2)
                            Text(tag.rawValue).font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(on ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10),
                                    in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? Color.accentColor : .clear, lineWidth: 1))
                        .foregroundStyle(on ? Color.accentColor : .secondary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: compact ? 70 : 96)
                if notes.isEmpty {
                    Text("What actually decided it? e.g. “their Mortis dove my backline every time”, “first pick should have been an anti-tank”, “Kenji felt bad on this map”.")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(.horizontal, 11).padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        }
    }
}

/// Read-only rendering of saved notes.
struct MatchNotesDisplay: View {
    let record: MatchRecord

    var body: some View {
        if record.hasNotes {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR NOTES").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                if !record.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(record.tags) { tag in
                            HStack(spacing: 5) {
                                Image(systemName: tag.symbol).font(.caption2)
                                Text(tag.rawValue).font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                if let n = record.notes, !n.isEmpty {
                    Text(n).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
