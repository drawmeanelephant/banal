import Foundation
#if canImport(Contacts)
import Contacts
#endif

public enum ContactMarkdownFormatter: Sendable {
    /// Formats contact components into Markdown.
    ///
    /// - If email is provided: `[Full Name](mailto:email)` (or `[email](mailto:email)` if name is empty).
    /// - If phone is provided and email is absent: `[Full Name](tel:phone)` (or `[phone](tel:phone)` if name is empty).
    /// - If only name is provided: `Full Name`.
    /// - If all are empty/nil: `""`.
    public static func format(name: String?, email: String? = nil, phone: String? = nil) -> String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedEmail.isEmpty {
            let displayName = trimmedName.isEmpty ? trimmedEmail : trimmedName
            return "[\(displayName)](mailto:\(trimmedEmail))"
        } else if !trimmedPhone.isEmpty {
            let displayName = trimmedName.isEmpty ? trimmedPhone : trimmedName
            return "[\(displayName)](tel:\(trimmedPhone))"
        } else if !trimmedName.isEmpty {
            return trimmedName
        } else {
            return ""
        }
    }

    #if canImport(Contacts)
    /// Formats a `CNContact` into Markdown.
    public static func format(contact: CNContact) -> String {
        let name = fullName(for: contact)
        let email = contact.emailAddresses.first?.value as? String
        let phone = contact.phoneNumbers.first?.value.stringValue
        return format(name: name, email: email, phone: phone)
    }

    /// Formats a specific selected `CNContactProperty` (e.g. specific email or phone property).
    public static func format(contactProperty: CNContactProperty) -> String {
        let contact = contactProperty.contact
        let name = fullName(for: contact)
        if contactProperty.key == CNContactEmailAddressesKey, let email = contactProperty.value as? String {
            return format(name: name, email: email, phone: nil)
        } else if contactProperty.key == CNContactPhoneNumbersKey {
            if let phoneNumber = contactProperty.value as? CNPhoneNumber {
                return format(name: name, email: nil, phone: phoneNumber.stringValue)
            } else if let phoneStr = contactProperty.value as? String {
                return format(name: name, email: nil, phone: phoneStr)
            }
        }
        return format(contact: contact)
    }

    /// Extracts a formatted full name or organization name from a `CNContact`.
    public static func fullName(for contact: CNContact) -> String {
        if let formatted = CNContactFormatter.string(from: contact, style: .fullName),
           !formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let parts = [contact.givenName, contact.middleName, contact.familyName].filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        if !contact.organizationName.isEmpty {
            return contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    #endif
}
