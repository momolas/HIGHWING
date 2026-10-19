// Copyright (C) 2019 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import GroundSdk
import SdkCore

/// Generic piloting command encoder
protocol PilotingCommandEncoder: NoAckCmdEncoder {
    /// Encoder of the current piloting command that should be sent to the device.
    ///
    /// - Note: closure `encoder` is called in a separate thread. This closure must not block.
    var encoder: () -> (ArsdkCommandEncoder?) { get }

    /// The piloting command
    var pilotingCommand: PilotingCommand { get }

    /// Period at which piloting command should be encoded.
    var pilotingCommandPeriod: Int32 { get }

    /// Updates the current piloting command roll value.
    ///
    /// - Parameter roll: roll value to set
    /// - Returns: true if setting this value changed the piloting command, false otherwise
    func set(roll: Int) -> Bool

    /// Updates the current piloting command pitch value.
    ///
    /// - Parameter pitch: pitch value to set
    /// - Returns: true if setting this value changed the piloting command, false otherwise
    func set(pitch: Int) -> Bool

    /// Updates the current piloting command yaw value.
    ///
    /// - Parameter yaw: yaw value to set
    /// - Returns: true if setting this value changed the piloting command, false otherwise
    func set(yaw: Int) -> Bool

    /// Updates the current piloting command gaz value.
    ///
    /// - Parameter gaz: gaz value to set
    /// - Returns: true if setting this value changed the piloting command, false otherwise
    func set(gaz: Int) -> Bool

    /// Reset all the values of the piloting command to their default (0).
    func reset()
}

/// A generic piloting command that may be encoded into various specific piloting ArsdkCommands.
///
/// - Note: the piloting command value fields are written to from the main thread while they are read from
/// the pcmd loop that runs in the pomp loop thread.
struct PilotingCommand {
    /// Pitch value
    private(set) var pitch = 0
    /// Roll value
    private(set) var roll = 0
    /// Yaw value
    private(set) var yaw = 0
    /// Gaz value
    private(set) var gaz = 0
    /// Flag value
    var flag: UInt {
        return (roll == 0 && pitch == 0) ? 0 : 1
    }

    /// private constructor
    private init() {

    }

    /// Base for a PilotingCommand encoder.
    class Encoder {
        let type = ArsdkNoAckCmdType.piloting

        /// Lock protecting concurrent access between the main thread and the pomp loop thread.
        fileprivate let lock = NSLock()

        /// Backing storage for current piloting command.
        private var _pilotingCommand = PilotingCommand()

        /// Current piloting command that is read and encoded by the pcmd loop.
        var pilotingCommand: PilotingCommand {
            lock.lock()
            defer { lock.unlock() }
            return _pilotingCommand
        }

        /// Private constructor
        fileprivate init() {}

        /// Updates the current piloting command roll value.
        ///
        /// - Parameter roll: roll value to set
        /// - Returns: true if setting this value changed the piloting command, false otherwise
        func set(roll: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if _pilotingCommand.roll != roll {
                _pilotingCommand.roll = roll
                return true
            }
            return false
        }

        /// Updates the current piloting command pitch value.
        ///
        /// - Parameter pitch: pitch value to set
        /// - Returns: true if setting this value changed the piloting command, false otherwise
        func set(pitch: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if _pilotingCommand.pitch != pitch {
                _pilotingCommand.pitch = pitch
                return true
            }
            return false
        }

        /// Updates the current piloting command yaw value.
        ///
        /// - Parameter yaw: yaw value to set
        /// - Returns: true if setting this value changed the piloting command, false otherwise
        func set(yaw: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if _pilotingCommand.yaw != yaw {
                _pilotingCommand.yaw = yaw
                return true
            }
            return false
        }

        /// Updates the current piloting command gaz value.
        ///
        /// - Parameter gaz: gaz value to set
        /// - Returns: true if setting this value changed the piloting command, false otherwise
        func set(gaz: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if _pilotingCommand.gaz != gaz {
                _pilotingCommand.gaz = gaz
                return true
            }
            return false
        }

        /// Reset all the values of the piloting command to their default (0).
        func reset() {
            lock.lock()
            defer { lock.unlock() }
            _pilotingCommand = PilotingCommand()
        }

        /// Base for ARDrone3 family piloting command encoders.
        ///
        /// Anafi family piloting command encoders use a loop period of 50 milliseconds.
        ///
        /// Handles timestamp/sequence number generation.
        class Anafi: Encoder {
            /// Period at which piloting command should be encoded.
            let pilotingCommandPeriod = Int32(50)

            /// Sequence number seed.
            var seqNr: UInt8 = 0

            override func reset() {
                super.reset()
                lock.lock()
                seqNr = 0
                lock.unlock()
            }

            /// Generates subsequent piloting command sequence number and timestamp.
            ///
            /// - Returns: sequence number to use to encode next command
            func nextSequenceNumber() -> UInt {
                lock.lock()
                seqNr = seqNr &+ 1
                let currentSeq = seqNr
                lock.unlock()
                let timestamp = UInt32(((TimeProvider.timeInterval) * 1000)
                    .truncatingRemainder(dividingBy: Double(UInt32.max)))
                let seqVal = UInt32(currentSeq) << 24
                let timestampVal = timestamp & ((1 << 24) - 1)
                return UInt(timestampVal | seqVal)
            }
        }

        /// Implementation of a PilotingCommand encoder for all Anafi copters.
        class AnafiCopter: Encoder.Anafi, PilotingCommandEncoder {

            var encoder: () -> (ArsdkCommandEncoder?) {
                return encoderBlock
            }

            /// Encoder of the current piloting command that should be sent to the device.
            private var encoderBlock: (() -> (ArsdkCommandEncoder))!

            /// Constructor
            override init() {
                super.init()
                encoderBlock = { [unowned self] in
                    let cmd = self.pilotingCommand
                    let flag = cmd.flag
                    // negate pitch: positive pitch from the drone POV means tilted towards ground (i.e. forward move),
                    // negative pitch means tilted towards sky (i.e. backward move)
                    let pitch = -cmd.pitch
                    let roll = cmd.roll
                    let yaw = cmd.yaw
                    let gaz = cmd.gaz
                    return ArsdkFeatureArdrone3Piloting.pCMDEncoder(
                        flag: flag, roll: roll, pitch: pitch, yaw: yaw, gaz: gaz,
                        timestampandseqnum: self.nextSequenceNumber())
                }
            }
        }

        /// Implementation of a PilotingCommand encoder for all ARDrone3 family planes.
        class Ardrone3Plane: Encoder.Anafi, PilotingCommandEncoder {

            var encoder: () -> (ArsdkCommandEncoder?) {
                return encoderBlock
            }

            /// Encoder of the current piloting command that should be sent to the device.
            private var encoderBlock: (() -> (ArsdkCommandEncoder))!

            /// Constructor
            override init() {
                super.init()
                encoderBlock = { [unowned self] in
                    let cmd = self.pilotingCommand
                    let flag: UInt = 1 // Do not use the piloting command flag
                    let pitch = cmd.pitch
                    let roll = cmd.roll
                    let yaw = 0
                    let gaz = cmd.gaz
                    return ArsdkFeatureArdrone3Piloting.pCMDEncoder(
                        flag: flag, roll: roll, pitch: pitch, yaw: yaw, gaz: gaz,
                        timestampandseqnum: self.nextSequenceNumber())
                }
            }
        }
    }
}
