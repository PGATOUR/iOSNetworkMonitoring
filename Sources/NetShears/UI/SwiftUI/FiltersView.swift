import SwiftUI

struct FiltersView: View {
    @State var showOnlyGQLQueries: Bool
    @State var showOnlyRestRequest: Bool
    @State var showGQLandREST: Bool
    @State var filterOutConnectivityPing: Bool
    @State var cloudinaryImagesOnly: Bool
    
    var didClose:
        (
            _ showOnlyGQLQueries: Bool,
            _ showOnlyRestRequest: Bool,
            _ showGQLandREST: Bool,
            _ filterOutConnectivityPing: Bool,
            _ cloudinaryImagesOnly: Bool
        ) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    Toggle("Show only GQL queries", isOn: $showOnlyGQLQueries)
                    Toggle("Show only REST requests", isOn: $showOnlyRestRequest)
                    Toggle("Show GQL and REST", isOn: $showGQLandREST)
                    Toggle("Filter out connectivity pings", isOn: $filterOutConnectivityPing)
                    Toggle("Show only Cloudinary images", isOn: $cloudinaryImagesOnly)
                }
                .padding()
            }
            .navigationTitle("Preset Filters")
        }
        .onDisappear {
            didClose(showOnlyGQLQueries, showOnlyRestRequest, showGQLandREST, filterOutConnectivityPing, cloudinaryImagesOnly)
        }
    }
}
