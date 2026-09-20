//
//  ContactPicker.swift
//  touchtime
//
//  Created on 13/09/2026.
//

import Contacts
import ContactsUI
import SwiftUI

/// Presents the system contact picker (CNContactPickerViewController) while
/// `isPresented` is true. Picking runs in the system's own process: the app
/// never asks for Contacts permission and only receives the one contact the
/// user taps, already reduced to the snapshot the countdown stores.
///
/// The picker is built to be presented modally, not embedded: hosted as
/// the content of a SwiftUI sheet it can come up blank, and it dismisses
/// itself in a way that fights the sheet's own dismissal. So this is an
/// invisible host view controller to attach as a `.background`, which
/// presents the picker the way UIKit does and lets it dismiss itself.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSelect: (CountdownItem.LinkedContact) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        if isPresented {
            context.coordinator.presentPicker(from: host)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        /// The picker while it is up; weak, so a presentation that never
        /// happened (host not in a window) leaves nothing behind.
        private weak var picker: CNContactPickerViewController?

        init(_ parent: ContactPicker) {
            self.parent = parent
        }

        func presentPicker(from host: UIViewController) {
            guard picker == nil, host.view.window != nil else { return }
            let picker = CNContactPickerViewController()
            picker.delegate = self
            // Tapping a contact returns it right away instead of opening
            // its card to choose a single property.
            picker.predicateForSelectionOfContact = NSPredicate(value: true)
            self.picker = picker
            host.present(picker, animated: true)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelect(CountdownItem.LinkedContact(contact))
            finish()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish()
        }

        /// The picker dismisses itself on both paths; the binding follows
        /// so the next tap can present it again.
        private func finish() {
            picker = nil
            parent.isPresented = false
        }
    }
}

extension CountdownItem.LinkedContact {
    /// The stored snapshot of a contact the picker returned. Every property
    /// is read only when the contact carries it, since asking for a key
    /// that was not fetched raises an exception.
    init(_ contact: CNContact) {
        identifier = contact.identifier

        // The name as Contacts shows it, or the company for a business
        // card; empty when the contact has neither.
        let nameKeys = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        let fullName = contact.areKeysAvailable([nameKeys])
            ? CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            : ""
        let organization = contact.isKeyAvailable(CNContactOrganizationNameKey) ? contact.organizationName : ""
        name = fullName.isEmpty ? organization : fullName

        // Initials for the monogram avatar ("JA" for Jane Appleseed); a
        // business card gets the first letter of its name.
        var components = PersonNameComponents()
        if contact.isKeyAvailable(CNContactGivenNameKey) {
            components.givenName = contact.givenName
        }
        if contact.isKeyAvailable(CNContactFamilyNameKey) {
            components.familyName = contact.familyName
        }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .abbreviated
        let abbreviated = formatter.string(from: components)
        initials = abbreviated.isEmpty ? (name.first.map { String($0).uppercased() } ?? "") : abbreviated

        // The mobile number when there is one, since that is the one to
        // text; otherwise whichever comes first.
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) {
            let numbers = contact.phoneNumbers
            let mobile = numbers.first { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone }
            phoneNumber = (mobile ?? numbers.first)?.value.stringValue
        } else {
            phoneNumber = nil
        }

        thumbnailImageData = contact.isKeyAvailable(CNContactThumbnailImageDataKey) ? contact.thumbnailImageData : nil
    }
}
