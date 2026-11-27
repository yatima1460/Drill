import SwiftUI

struct SearchSettings: View {
    @ObservedObject var model: SearchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Search inside Photos libraries", isOn: Binding(
                get: { model.searchInsidePhotosLibraries },
                set: model.setSearchInsidePhotosLibraries
            ))
            .toggleStyle(.checkbox)

            Text("The library itself stays searchable. Searching its contents may trigger a macOS permission request.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
