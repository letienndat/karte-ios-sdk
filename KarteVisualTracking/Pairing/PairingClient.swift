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

import KarteCore
import KarteUtilities
import UIKit

internal class PairingClient {
    var app: KarteApp
    var account: Account
    var timer: SafeTimer
    var isPaired = false {
        didSet {
            let visualTracking = VisualTracking.shared
            visualTracking.delegate?.visualTrackingDevicePairingStatusUpdated?(visualTracking, isPaired: isPaired)
        }
    }

    private var backgroundTask = BackgroundTask()

    init(app: KarteApp, account: Account) {
        self.app = app
        self.account = account

        let queue = DispatchQueue(
            label: "io.karte.vt.pairing",
            qos: DispatchQoS(qosClass: .utility, relativePriority: 1_000)
        )

        let timer = SafeTimer(timeInterval: .seconds(5), queue: queue)
        self.timer = timer
        self.backgroundTask.delegate = self
    }

    func startPairing() {
        guard let request = PairingRequest(app: app, account: account) else {
            return
        }
        Session.send(request) { [weak self] result in
            switch result {
            case .success:
                Logger.info(tag: .visualTracking, message: "Pairing was successful.")
                self?.startPolling()

            case .failure(let error):
                Logger.error(tag: .visualTracking, message: "Failed to pairing request. \(error.localizedDescription)")
            }
        }
    }

    func stopPairing() {
        if isPaired {
            stopPolling()
        }
    }

    private func startPolling() {
        if isPaired {
            return
        }

        isPaired = true

        backgroundTask.observeLifecycle()

        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        timer.eventHandler = { [weak self] in
            self?.heartbeat()
        }
        timer.resume()
    }

    private func stopPolling() {
        guard isPaired else {
            return
        }

        timer.suspend()
        isPaired = false

        backgroundTask.unobserveLifecycle()

        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func heartbeat() {
        let request = PairingHeartbeatRequest(app: app, account: account)
        Session.send(request) { [weak self] result in
            switch result {
            case .success:
                Logger.verbose(tag: .visualTracking, message: "Heartbeat was successful.")

            case .failure(let error):
                Logger.error(tag: .visualTracking, message: "Failed to heartbeat request. \(error.localizedDescription)")
                self?.stopPolling()
            }
        }
    }

    deinit {
    }
}

extension PairingClient: BackgroundTaskDelegate {
    func backgroundTaskShouldStart(_ backgroundTask: BackgroundTask) -> Bool {
        true
    }

    func backgroundTaskWillStart(_ backgroundTask: BackgroundTask) {
        Logger.debug(tag: .visualTracking, message: "Start pairing in the background.")
    }

    func backgroundTaskDidFinish(_ backgroundTask: BackgroundTask) {
        Logger.debug(tag: .visualTracking, message: "Ends the pairing in the background.")
    }
}
