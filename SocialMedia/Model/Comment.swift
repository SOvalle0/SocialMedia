//
//  Comment.swift
//  SocialMedia
//
//  Created by Balaji on 30/12/22.
//

import SwiftUI
import FirebaseFirestoreSwift

struct Comment: Identifiable,Codable {
    @DocumentID var id: String?
    var comment: String
    var postedTime: Date = .init()
    var userName: String
    var userUID: String
    
    enum CodingKeys: CodingKey {
        case id
        case comment
        case postedTime
        case userName
        case userUID
    }
}
