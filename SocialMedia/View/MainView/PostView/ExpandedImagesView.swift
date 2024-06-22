//
//  ExpandedImagesView.swift
//  SocialMedia
//
//  Created by Balaji on 30/12/22.
//

import SwiftUI
import SDWebImageSwiftUI

struct ExpandedImagesView: View {
    var imageURLs: [URL]
    @Binding var pageIndex: Int
    /// - View Properties
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        TabView(selection: $pageIndex){
            ForEach(imageURLs,id: \.self){url in
                let index = imageURLs.indexOf(url)
                WebImage(url: url,options: [.scaleDownLargeImages])
                    .purgeable(true)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .tag(index)
            }
        }
        .tabViewStyle(.page)
        .hAlign(.center).vAlign(.center)
        .background {
            Color.black
                .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(15)
                    .contentShape(Rectangle())
            }
        }
    }
}
