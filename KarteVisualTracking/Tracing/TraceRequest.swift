//
//  Copyright 2020 PLAID, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import KarteCore
import KarteUtilities

internal struct TraceRequest: Request {
    typealias Response = String

    let configuration: Configuration
    let appKey: String
    let appInfo: AppInfo
    let visitorId: String
    let account: Account
    let action: ActionProtocol
    let image: Data?

    var baseURL: URL {
        configuration.baseURL
    }

    var method: HTTPMethod {
        .post
    }

    var path: String {
        "/v0/native/auto-track/trace"
    }

    var headerFields: [String: String] {
        [
            "X-KARTE-App-Key": appKey,
            "X-KARTE-Auto-Track-Account-Id": account.id
        ]
    }

    private let boundary: String

    public var contentType: String {
        return "multipart/form-data; boundary=\(boundary)"
    }

    init?(
        app: KarteApp,
        account: Account,
        action: ActionProtocol,
        image: Data?
    ) {
        guard let appInfo = app.appInfo else {
            return nil
        }
        self.configuration = app.configuration
        self.appKey = app.appKey
        self.appInfo = appInfo
        self.visitorId = app.visitorId
        self.account = account
        self.action = action
        self.image = image
        self.boundary = String(
            format: "%08x%08x",
            UInt32.random(in: 0...UInt32.max),
            UInt32.random(in: 0...UInt32.max)
        )
    }

    func buildBody() throws -> Data? {
        var parts: [MultipartFormDataBody.Part] = []

        do {
            let data = try createJSONEncoder().encode(PartData(action: action, appInfo: appInfo, visitorId: visitorId))
            let part = MultipartFormDataBody.Part(data: data, name: "trace")
            parts.append(part)
        } catch {
            Logger.error(tag: .visualTracking, message: "Failed to encode JSON body for trace request: \(error)")
        }

        if let image = image {
            let part = MultipartFormDataBody.Part(data: image, name: "image", mimeType: .imageJpeg, fileName: "image")
            parts.append(part)
        }

        return try MultipartFormDataBody(parts: parts, boundary: boundary).asData()
    }

    func parse(data: Data, urlResponse: HTTPURLResponse) throws -> Response {
        guard let response = String(data: data, encoding: .utf8) else {
            throw ResponseParserError.invalidData(data)
        }
        return response
    }
}

extension TraceRequest {
    struct PartData: Codable {
        var os: String
        var visitorId: String
        var values: Values

        init(action: ActionProtocol, appInfo: AppInfo, visitorId: String) {
            self.os = "iOS"
            self.visitorId = visitorId
            self.values = Values(action: action, appInfo: appInfo)
        }
    }
}

extension TraceRequest.PartData {
    struct Values: Codable {
        var action: String
        var actionId: String?
        var view: String?
        var viewController: String?
        var targetText: String?
        var appInfo: AppInfo

        init(action: ActionProtocol, appInfo: AppInfo) {
            self.action = action.action
            self.actionId = action.actionId
            self.view = action.screenName
            self.viewController = action.screenHostName
            self.targetText = action.targetText
            self.appInfo = appInfo
        }
    }

    enum CodingKeys: String, CodingKey {
        case os
        case visitorId = "visitor_id"
        case values
    }
}

extension TraceRequest.PartData.Values {
    enum CodingKeys: String, CodingKey {
        case action
        case actionId       = "action_id"
        case view
        case viewController = "view_controller"
        case targetText     = "target_text"
        case appInfo        = "app_info"
    }
}
