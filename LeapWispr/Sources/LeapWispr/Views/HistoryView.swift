import SwiftUI
import AppKit

public struct HistoryView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var searchText = ""
    @State private var copiedId: UUID?
    
    private var filteredHistory: [DictationRecord] {
        if searchText.isEmpty {
            return settings.history
        }
        return settings.history.filter {
            $0.transformedText.localizedCaseInsensitiveContains(searchText) ||
            $0.rawText.localizedCaseInsensitiveContains(searchText) ||
            $0.appName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar & Clear
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search past dictations...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if !settings.history.isEmpty {
                    Button("Clear History") {
                        settings.clearHistory()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // List
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No dictations recorded yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Double-tap fn anywhere to start speaking.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredHistory) { record in
                    dictationRow(record)
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 520, height: 440)
    }
    
    private func dictationRow(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.tone.emoji)
                Text(record.tone.displayName)
                    .font(.system(size: 11, weight: .bold))
                
                Text("in \(record.appName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(record.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(record.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Button(action: { copyToClipboard(record) }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedId == record.id ? "checkmark" : "doc.on.doc")
                        Text(copiedId == record.id ? "Copied" : "Copy")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            Text(record.transformedText)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
            
            if record.tone != .raw && !record.rawText.isEmpty {
                Text("Spoken: \"\(record.rawText)\"")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func copyToClipboard(_ record: DictationRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.transformedText, forType: .string)
        copiedId = record.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedId == record.id { copiedId = nil }
        }
    }
}
