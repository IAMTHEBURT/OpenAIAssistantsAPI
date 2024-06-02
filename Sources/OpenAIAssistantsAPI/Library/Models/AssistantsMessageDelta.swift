//
//  AssistantsMessageDelta.swift
//  CooksMate
//
//  Created by Ivan Lvov on 26.05.2024.
//

import Foundation

struct AssistantsMessageDelta: Codable {
    let id: String
    let object: String
    let delta: DeltaContent

    struct DeltaContent: Codable {
        let content: [Content]

        struct Content: Codable {
            let index: Int
            let type: String
            let text: Text

            struct Text: Codable {
                let value: String
            }
        }
    }
}
