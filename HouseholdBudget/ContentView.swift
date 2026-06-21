import SwiftUI

struct ContentView: View {
    var body: some View {
        WalletRootView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WalletStore())
    }
}
