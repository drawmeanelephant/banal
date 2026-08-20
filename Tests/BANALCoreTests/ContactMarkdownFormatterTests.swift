import XCTest
#if canImport(Contacts)
import Contacts
#endif
@testable import BANALCore

final class ContactMarkdownFormatterTests: XCTestCase {
    func testFormatNameAndEmail() {
        let result = ContactMarkdownFormatter.format(name: "John Appleseed", email: "john@apple.com")
        XCTAssertEqual(result, "[John Appleseed](mailto:john@apple.com)")
    }

    func testFormatNameAndEmailWithWhitespace() {
        let result = ContactMarkdownFormatter.format(name: "  Jane Doe  ", email: "  jane@example.com \n")
        XCTAssertEqual(result, "[Jane Doe](mailto:jane@example.com)")
    }

    func testFormatNameAndPhoneWithoutEmail() {
        let result = ContactMarkdownFormatter.format(name: "John Appleseed", email: nil, phone: "+1 (555) 123-4567")
        XCTAssertEqual(result, "[John Appleseed](tel:+1 (555) 123-4567)")
    }

    func testFormatNameEmailAndPhonePrefersEmail() {
        let result = ContactMarkdownFormatter.format(name: "John Appleseed", email: "john@apple.com", phone: "+15551234567")
        XCTAssertEqual(result, "[John Appleseed](mailto:john@apple.com)")
    }

    func testFormatNameOnly() {
        let result = ContactMarkdownFormatter.format(name: "John Appleseed", email: nil, phone: nil)
        XCTAssertEqual(result, "John Appleseed")
    }

    func testFormatEmailOnly() {
        let result = ContactMarkdownFormatter.format(name: nil, email: "developer@apple.com", phone: nil)
        XCTAssertEqual(result, "[developer@apple.com](mailto:developer@apple.com)")
    }

    func testFormatPhoneOnly() {
        let result = ContactMarkdownFormatter.format(name: nil, email: nil, phone: "555-0199")
        XCTAssertEqual(result, "[555-0199](tel:555-0199)")
    }

    func testFormatEmptyAndNil() {
        XCTAssertEqual(ContactMarkdownFormatter.format(name: nil, email: nil, phone: nil), "")
        XCTAssertEqual(ContactMarkdownFormatter.format(name: "", email: "", phone: ""), "")
        XCTAssertEqual(ContactMarkdownFormatter.format(name: "   ", email: "  ", phone: " "), "")
    }

    #if canImport(Contacts)
    func testFormatCNContactWithNameAndEmail() {
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Appleseed"
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "john@apple.com" as NSString)
        ]

        let result = ContactMarkdownFormatter.format(contact: contact)
        XCTAssertEqual(result, "[John Appleseed](mailto:john@apple.com)")
    }

    func testFormatCNContactWithNameAndPhone() {
        let contact = CNMutableContact()
        contact.givenName = "Jane"
        contact.familyName = "Smith"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1-555-9876"))
        ]

        let result = ContactMarkdownFormatter.format(contact: contact)
        XCTAssertEqual(result, "[Jane Smith](tel:+1-555-9876)")
    }

    func testFormatCNContactWithOrganizationOnly() {
        let contact = CNMutableContact()
        contact.organizationName = "Apple Inc."
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelWork, value: "contact@apple.com" as NSString)
        ]

        let result = ContactMarkdownFormatter.format(contact: contact)
        XCTAssertEqual(result, "[Apple Inc.](mailto:contact@apple.com)")
    }

    func testFormatCNContactPropertyEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Alice"
        contact.familyName = "Baker"
        contact.emailAddresses = [
            CNLabeledValue(label: CNLabelHome, value: "alice.home@example.com" as NSString),
            CNLabeledValue(label: CNLabelWork, value: "alice.work@example.com" as NSString)
        ]

        let direct = ContactMarkdownFormatter.format(name: ContactMarkdownFormatter.fullName(for: contact), email: "alice.work@example.com")
        XCTAssertEqual(direct, "[Alice Baker](mailto:alice.work@example.com)")
    }
    #endif
}
