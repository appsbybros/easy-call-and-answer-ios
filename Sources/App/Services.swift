import SwiftUI
import ContactsUI
import StoreKit
import UserNotifications
import AVFoundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

@MainActor final class Library: ObservableObject {
    @Published var value = Snapshot()
    @Published var error: String?
    let demonstration: Bool
    private let file: URL
    private var readFailed = false
    init() {
        #if DEBUG
        demonstration = ProcessInfo.processInfo.arguments.contains("--screenshots")
        #else
        demonstration = false
        #endif
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("EasyCall", isDirectory: true)
        file = folder.appendingPathComponent("people.json")
        if demonstration {
            value.people = [Person(name:"Maya",phone:"+12025550101",note:L("Ask about the weekend"),color:0),Person(name:"Daniel",phone:"+12025550102",note:L("Best time: after lunch"),color:1),Person(name:L("Family"),phone:"+12025550103",color:2),Person(name:L("Pharmacy"),phone:"+12025550104",note:L("Have your reference number ready"),color:3)]
        } else if FileManager.default.fileExists(atPath:file.path) {
            do { value = try LibraryCodec.decode(Data(contentsOf:file)) }
            catch { readFailed = true; self.error = L("Your saved contacts could not be opened. They have not been replaced. Close and reopen the app, or contact support.") }
        }
    }
    @discardableResult func save() -> Bool {
        guard !demonstration else { return true }
        guard !readFailed else { error = L("Saved data needs attention before you can make changes."); return false }
        do {
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
            try LibraryCodec.encode(value).write(to:file,options:[.atomic,.completeUntilFirstUserAuthentication])
            return true
        } catch { self.error = L("Your changes could not be saved. Please try again."); return false }
    }
    func upsert(_ person: Person) -> Bool {
        let before = value
        if let index = value.people.firstIndex(where:{$0.id == person.id}) { value.people[index] = person }
        else if value.people.count < 100 { value.people.append(person) }
        else { error = L("Your contact list is full."); return false }
        if !save() { value = before; return false }; return true
    }
    func remove(_ person: Person) {
        let before = value; let ids = value.reminders.filter{$0.personID == person.id}.map{ $0.id.uuidString }
        value.remove(person.id)
        if save() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:ids) }
        else { value = before }
    }
    func recordVisit() {
        guard value.trialStart != nil else { return }
        value.latestSeen = max(Date(),value.latestSeen ?? .distantPast); save()
    }
}

@MainActor final class Calling: ObservableObject {
    @Published var message: String?
    @Published var opening = false
    private var gate = DialGate()
    func dial(_ phone: String, demonstration: Bool, faceTime: Bool = false) {
        guard !demonstration else { message = L("This is a practice contact. No call was placed."); return }
        guard let url = PhoneNumber.url(phone,faceTime:faceTime) else { message = L("Check this phone number. Use digits and an optional country code."); return }
        guard UIApplication.shared.canOpenURL(url) else { message = L("Calling is not available on this device. You can copy the number and use your phone."); return }
        guard gate.admit(now:Date()), !opening else { return }
        opening = true
        UIApplication.shared.open(url,options:[:]) { [weak self] accepted in
            Task { @MainActor in
                self?.opening = false
                // A URL acceptance is only a handoff, never evidence that someone answered.
                if !accepted { self?.message = L("The Phone app did not open. Nothing was dialed by Easy Call. Please try again.") }
            }
        }
    }
}

@MainActor final class Purchases: ObservableObject {
    static let productID = "com.appsbybros.easycall.lifetime"
    @Published var unlocked = false
    @Published var product: Product?
    @Published var busy = false
    @Published var message: String?
    private var listener: Task<Void,Never>?
    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish(); await self?.refresh()
                }
            }
        }
        Task { await refresh() }
    }
    deinit { listener?.cancel() }
    func refresh() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,transaction.revocationDate == nil { found = true }
        }
        unlocked = found
        do { product = try await Product.products(for:[Self.productID]).first }
        catch { product = nil }
    }
    func buy() async {
        guard let product,!busy else { return }; busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { message = L("The purchase could not be verified. Please restore purchases."); return }
                await transaction.finish(); await refresh()
            case .pending: message = L("Your purchase is awaiting approval.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = L("The purchase did not finish. You can try again.") }
    }
    func restore() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = unlocked ? L("Purchase restored.") : L("No upgrade was found for this Apple Account.") }
        catch { message = L("Restore could not finish. Please try again.") }
    }
}

struct ContactPicker: UIViewControllerRepresentable {
    var selected: (Person) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(parent:self) }
    func makeUIViewController(context:Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format:"phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value:false)
        picker.predicateForSelectionOfProperty = NSPredicate(format:"key == 'phoneNumbers'")
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }
    func updateUIViewController(_ vc:CNContactPickerViewController,context:Context) {}
    final class Coordinator: NSObject,CNContactPickerDelegate {
        let parent: ContactPicker
        init(parent:ContactPicker) { self.parent = parent }
        func contactPicker(_ picker:CNContactPickerViewController,didSelect property:CNContactProperty) {
            guard let phone = property.value as? CNPhoneNumber else { return }
            let contact = property.contact
            let name = CNContactFormatter.string(from:contact,style:.fullName) ?? phone.stringValue
            var photo: Data?
            if let data = contact.thumbnailImageData,let image = UIImage(data:data) {
                let size = CGSize(width:320,height:320)
                photo = UIGraphicsImageRenderer(size:size).jpegData(withCompressionQuality:0.8) { _ in image.draw(in:CGRect(origin:.zero,size:size)) }
            }
            parent.selected(Person(name:name,phone:phone.stringValue,photo:photo)); parent.dismiss()
        }
        func contactPickerDidCancel(_ picker:CNContactPickerViewController) { parent.dismiss() }
    }
}

@MainActor enum Reminders {
    enum Failure: Error { case invalidDate, permissionDenied }
    static func schedule(person:Person,date:Date) async throws -> CallReminder {
        guard date > Date().addingTimeInterval(30) else { throw Failure.invalidDate }
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options:[.alert,.sound]) else { throw Failure.permissionDenied }
        let reminder = CallReminder(personID:person.id,date:date)
        let content = UNMutableNotificationContent()
        content.title = L("Time for a call")
        content.body = person.name; content.sound = .default
        content.userInfo = ["personID":person.id.uuidString]
        let trigger = UNCalendarNotificationTrigger(dateMatching:Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:date),repeats:false)
        try await center.add(UNNotificationRequest(identifier:reminder.id.uuidString,content:content,trigger:trigger))
        return reminder
    }
}
