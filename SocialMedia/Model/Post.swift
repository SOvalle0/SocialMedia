//
//  Post.swift
//  SocialMedia
//
//  Created by Balaji on 25/12/22.
//

import SwiftUI
import FirebaseFirestoreSwift

// MARK: Post Model
struct Post: Identifiable,Codable,Equatable,Hashable {
    @DocumentID var id: String?
    var text: String
    var imageURLs: [URL] = []
    var imageReferenceIDs: [String] = []
    var publishedDate: Date = Date()
    var likedIDs: [String] = []
    var dislikedIDs: [String] = []
    // MARK: Basic User Info
    var userName: String
    var userUID: String
    var userProfileURL: URL
    
    enum CodingKeys: CodingKey {
        case id
        case text
        case imageURLs
        case imageReferenceIDs
        case publishedDate
        case likedIDs
        case dislikedIDs
        case userName
        case userUID
        case userProfileURL
    }
}
