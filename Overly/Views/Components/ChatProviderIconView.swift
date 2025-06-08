import SwiftUI

struct ChatProviderIconView: View {
    let provider: ChatProviderType
    
    var body: some View {
        Group {
            if provider.isSystemIcon {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Image(provider.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
            }
        }
        .foregroundColor(.primary)
    }
} 