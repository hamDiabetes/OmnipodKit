//
//  CheckInsertedCannulaView.swift
//  OmnipodKit
//
//  From OmniBLE/PumpManageUI/Views/CheckInsertedCannulaView.swift
//  Created by Pete Schwamb on 4/3/20.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
import AVFoundation

struct CheckInsertedCannulaView: View {
    @Environment(\.colorScheme) private var currentColorScheme
    
    @State private var cancelModalIsPresented: Bool = false
    @State private var flashlightOn: Bool = false
    @State private var siteSide: PodInsertionSite.Side?
    @State private var siteArea: PodInsertionSite.Area?
    
    private var didRequestDeactivation: () -> Void
    private var wasInsertedProperly: () -> Void
    private var podActivatedAt: Date?

    init(podActivatedAt: Date? = nil, didRequestDeactivation: @escaping () -> Void, wasInsertedProperly: @escaping () -> Void) {
        self.podActivatedAt = podActivatedAt
        self.didRequestDeactivation = didRequestDeactivation
        self.wasInsertedProperly = wasInsertedProperly
    }

    var body: some View {
        GuidePage(content: {
            VStack {
                LeadingImage("Cannula Inserted")
            
                HStack {
                    FrameworkLocalText("Is the cannula inserted properly?", comment: "Question to confirm the cannula is inserted properly").bold()
                    Spacer()
                }
                HStack {
                    FrameworkLocalText("The window on the top of the Pod should be colored pink when the cannula is properly inserted into the skin.", comment: "Description of proper cannula insertion").fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }.padding(.vertical)
                
                 // Show the button either if the device supports it, or
                 // we're in xcode preview mode
                 if hasFlashlight || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                     Toggle(isOn: $flashlightOn) {
                         Label("Flashlight", systemImage: flashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                             .labelStyle(.iconOnly)
                             .imageScale(.large)
                     }
                     .toggleStyle(FlashlightToggleStyle())
                     .onChange(of: flashlightOn) { v in
                         setFlashlightState(state: v)
                     }
                 }

                siteSelector
                    .padding(.top)
            }

        }) {
            VStack(spacing: 10) {
                Button(action: {
                    flashlightOn = false
                    PodInsertionSite.post(side: siteSide, area: siteArea, podActivatedAt: podActivatedAt)
                    self.wasInsertedProperly()
                }) {
                    Text(LocalizedString("Yes", comment: "Button label for user to answer cannula was properly inserted"))
                        .actionButtonStyle(.primary)
                }
                Button(action: {
                    flashlightOn = false
                    self.didRequestDeactivation()
                }) {
                    Text(LocalizedString("No", comment: "Button label for user to answer cannula was not properly inserted"))
                        .actionButtonStyle(.destructive)
                }
            }.padding()
        }
        .animation(.default, value: flashlightOn)
        .alert(isPresented: $cancelModalIsPresented) { cancelPairingModal }
        .navigationTitle(LocalizedString("Check Cannula", comment: "navigation title for Check Cannula"))
        .navigationBarTitleDisplayMode(.automatic)
        .navigationBarItems(trailing: cancelButton)
        .navigationBarBackButtonHidden(true)
    }
    
    var siteSelector: some View {
        HStack {
            Picker(LocalizedString("Side", comment: "Label for pod site side picker"), selection: $siteSide) {
                ForEach(PodInsertionSite.Side.allCases, id: \.self) { side in
                    Text(side.shortLabel).tag(Optional(side))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 96)

            Picker(LocalizedString("Site", comment: "Label for pod site area picker"), selection: $siteArea) {
                ForEach(PodInsertionSite.Area.allCases, id: \.self) { area in
                    Text(area.shortLabel).tag(Optional(area))
                }
            }
            .pickerStyle(.segmented)
        }
        .accessibility(identifier: "pod_site_selector")
    }

    var cancelButton: some View {
        Button(LocalizedString("Cancel", comment: "Cancel button text in navigation bar on insert cannula screen")) {
            cancelModalIsPresented = true
        }
        .accessibility(identifier: "button_cancel")
    }

    var cancelPairingModal: Alert {
        return Alert(
            title: FrameworkLocalText("Are you sure you want to cancel Pod setup?", comment: "Alert title for cancel pairing modal"),
            message: FrameworkLocalText("If you cancel Pod setup, the current Pod will be deactivated and will be unusable.", comment: "Alert message body for confirm pod attachment"),
            primaryButton: .destructive(FrameworkLocalText("Yes, Deactivate Pod", comment: "Button title for confirm deactivation option"), action: { didRequestDeactivation() } ),
            secondaryButton: .default(FrameworkLocalText("No, Continue With Pod", comment: "Continue pairing button title of in pairing cancel modal"))
        )
    }

    
    var hasFlashlight: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.hasTorch
    }
    
    func setFlashlightState(state: Bool) -> Void {
        guard let device = AVCaptureDevice.default(for: .video) else {
            flashlightOn = false
            return
        }
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if state == true {
                    try device.setTorchModeOn(level: 1.0)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
                flashlightOn = false
            }
        }
    }
}

/// Where the pod was placed, chosen while checking the cannula. Optional and never blocks setup;
/// the host app hears about it through `selectedNotification` and can record it with the pod change.
public enum PodInsertionSite {
    public static let selectedNotification = Notification.Name("OmnipodKit.PodInsertionSiteSelected")
    public static let siteKey = "site"
    public static let podActivatedAtKey = "podActivatedAt"

    enum Side: String, CaseIterable {
        case left = "Left"
        case right = "Right"

        var shortLabel: String {
            switch self {
            case .left: return LocalizedString("L", comment: "Short label for left pod site")
            case .right: return LocalizedString("R", comment: "Short label for right pod site")
            }
        }
    }

    enum Area: String, CaseIterable {
        case arm = "Arm"
        case leg = "Leg"
        case tummy = "Tummy"
        case bum = "Bum"

        var shortLabel: String {
            switch self {
            case .arm: return LocalizedString("Arm", comment: "Short label for arm pod site")
            case .leg: return LocalizedString("Leg", comment: "Short label for leg pod site")
            case .tummy: return LocalizedString("Tum", comment: "Short label for tummy pod site")
            case .bum: return LocalizedString("Bum", comment: "Short label for bum pod site")
            }
        }
    }

    static func describe(side: Side?, area: Area?) -> String? {
        let parts = [side?.rawValue, area?.rawValue].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func post(side: Side?, area: Area?, podActivatedAt: Date?) {
        guard let site = describe(side: side, area: area) else { return }
        var userInfo: [String: Any] = [siteKey: site]
        userInfo[podActivatedAtKey] = podActivatedAt
        NotificationCenter.default.post(name: selectedNotification, object: nil, userInfo: userInfo)
    }
}

struct FlashlightToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            configuration.label
                .padding(.all, 22)
                .background(configuration.isOn ?
                    .white
                            :
                                colorScheme == .light ?
                            Color(UIColor.systemGray) :
                                Color(UIColor.systemBackground)
                )
                .foregroundStyle(configuration.isOn ? .blue : .white)
        }
        .buttonStyle(.plain)
        .containerShape(.circle)
        .shadow(
            color: configuration.isOn ? .yellow.opacity(0.5) : .white.opacity(0.0),
            radius: configuration.isOn ? 10 : 0
        )
    }
}

struct CheckInsertedCannulaView_Previews: PreviewProvider {
    static var previews: some View {
        CheckInsertedCannulaView(didRequestDeactivation: {}, wasInsertedProperly: {} )
    }
}
