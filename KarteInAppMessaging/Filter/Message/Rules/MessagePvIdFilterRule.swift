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

internal struct MessagePvIdFilterRule: MessageFilterRule {
    var request: TrackRequest
    var app: KarteApp?

    func filter(_ message: [String: JSONValue]) -> MessageFilterResult {
        guard let isEnabled = message.bool(forKeyPath: "campaign.native_app_display_limit_mode"), let pvService = app?.pvService, isEnabled else {
            return .include
        }
        if pvService.pvId(forSceneId: request.sceneId) == request.pvId {
            return .include
        }

        let match = pvService.originalPvId(forSceneId: request.sceneId) == request.pvId
        if match {
            return .include
        } else {
            return .exclude("The display is suppressed by native_app_display_limit_mode.")
        }
    }
}
