import AppKit
import BANALCore
#if canImport(ContactsUI)
import Contacts
import ContactsUI
#endif

@MainActor
public final class ContactPickerPresenter: NSObject {
    public static let shared = ContactPickerPresenter()

    #if canImport(ContactsUI)
    private var picker: CNContactPicker?
    private var onSelect: ((String) -> Void)?
    #endif

    public func present(
        relativeTo rect: NSRect = .zero,
        of view: NSView,
        preferredEdge: NSRectEdge = .maxY,
        onSelect: @escaping (String) -> Void
    ) {
        #if canImport(ContactsUI)
        let picker = CNContactPicker()
        self.picker = picker
        self.onSelect = onSelect
        picker.delegate = self
        picker.displayedKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactOrganizationNameKey,
        ]
        picker.showRelative(to: rect, of: view, preferredEdge: preferredEdge)
        #endif
    }
}

#if canImport(ContactsUI)
extension ContactPickerPresenter: @preconcurrency CNContactPickerDelegate {
    @MainActor
    public func contactPicker(_ picker: CNContactPicker, didSelect contact: CNContact) {
        let text = ContactMarkdownFormatter.format(contact: contact)
        if !text.isEmpty {
            onSelect?(text)
        }
        self.picker = nil
        self.onSelect = nil
    }

    @MainActor
    public func contactPicker(_ picker: CNContactPicker, didSelect contactProperty: CNContactProperty) {
        let text = ContactMarkdownFormatter.format(contactProperty: contactProperty)
        if !text.isEmpty {
            onSelect?(text)
        }
        self.picker = nil
        self.onSelect = nil
    }

    @MainActor
    public func contactPickerDidClose(_ picker: CNContactPicker) {
        self.picker = nil
        self.onSelect = nil
    }
}
#endif
