import SwiftUI

struct FiltersView: View {
    @State var filterOutConnectivityPing: Bool
    @State var cloudinaryImagesOnly: Bool
    
    var didClose:
        (
            _ filterOutConnectivityPing: Bool,
            _ cloudinaryImagesOnly: Bool
        ) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    Toggle("Filter out connectivity pings", isOn: $filterOutConnectivityPing)
                    Toggle("Show only Cloudinary images", isOn: $cloudinaryImagesOnly)
                }
                .padding()
            }
            .navigationTitle("Preset Filters")
        }
        .onDisappear {
            didClose(filterOutConnectivityPing, cloudinaryImagesOnly)
        }
    }
}
