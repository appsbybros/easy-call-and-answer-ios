import SwiftUI
import UserNotifications

enum Palette {
    static let ink = Color(red:0.09,green:0.19,blue:0.24)
    static let teal = Color(red:0.02,green:0.36,blue:0.34)
    static let cream = Color(red:0.97,green:0.96,blue:0.92)
    static let gold = Color(red:0.96,green:0.77,blue:0.39)
    static let colors: [Color] = [Color(red:0.81,green:0.91,blue:0.86),Color(red:0.86,green:0.85,blue:0.96),Color(red:0.99,green:0.86,blue:0.72),Color(red:0.79,green:0.89,blue:0.96)]
}
struct ActionStyle: ButtonStyle {
    var primary = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.title3.weight(.semibold)).frame(maxWidth:.infinity).frame(minHeight:64)
            .padding(.horizontal,16).foregroundStyle(primary ? .white : Palette.ink)
            .background(primary ? Palette.teal : .white,in:RoundedRectangle(cornerRadius:22))
            .overlay(RoundedRectangle(cornerRadius:22).strokeBorder(primary ? .clear : Palette.ink.opacity(0.18),lineWidth:1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
struct Page<Content:View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:24) { content }.frame(maxWidth:900).padding(24).frame(maxWidth:.infinity) }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.cream).foregroundStyle(Palette.ink)
    }
}
struct SectionTitle: View {
    var title: String; var subtitle: String
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text(L(title)).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text(L(subtitle)).font(.title3).fixedSize(horizontal:false,vertical:true)
        }
    }
}
struct Avatar: View {
    var person:Person; var size:CGFloat = 84
    var body: some View {
        Group {
            if let data = person.photo, let image = UIImage(data:data) { Image(uiImage:image).resizable().scaledToFill() }
            else { Text(person.initials).font(.system(size:size*0.35,weight:.bold,design:.rounded)).foregroundStyle(Palette.ink).frame(maxWidth:.infinity,maxHeight:.infinity).background(Palette.colors[abs(person.color % Palette.colors.count)]) }
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.32)).accessibilityHidden(true)
    }
}

struct HomeView: View {
    @EnvironmentObject private var library:Library
    @EnvironmentObject private var calling:Calling
    @EnvironmentObject private var purchases:Purchases
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var editing:Person?
    @State private var selected:Person?
    @State private var adding = false
    @State private var settings = false
    @State private var upgrade = false
    private var hasExtra:Bool { purchases.unlocked || library.value.trialActive(start:purchases.trialStart,now:Date()) }
    var body: some View {
        TabView(selection:$tab) {
            NavigationStack {
                Page {
                    if !type.isAccessibilitySize || library.value.people.isEmpty { HStack(alignment:.top,spacing:16) {
                        SectionTitle(title:"Your people.",subtitle:"A familiar face. A little closer.")
                        Spacer(minLength:0)
                        Image(systemName:"phone.fill").font(.system(size:30)).foregroundStyle(Palette.teal).frame(width:68,height:68).background(Palette.gold,in:RoundedRectangle(cornerRadius:24)).accessibilityHidden(true)
                    } }
                    if library.value.people.isEmpty {
                        VStack(alignment:.leading,spacing:20) {
                            Image(systemName:"person.2.fill").font(.system(size:52)).foregroundStyle(Palette.teal).accessibilityHidden(true)
                            Text(L("Start with someone you love")).font(.title.bold())
                            Text(L("Add a favorite from Contacts, or enter a name and number. Only the contacts you choose are saved here.")).font(.title3)
                        }.padding(28).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:28))
                    } else {
                        LazyVGrid(columns:[GridItem(.adaptive(minimum:type.isAccessibilitySize ? 300 : (library.value.largeCards ? 250 : 170)),spacing:16)],spacing:16) {
                            ForEach(library.value.people) { person in
                                VStack(alignment:.leading,spacing:16) {
                                    Button { selected = person } label: {
                                        VStack(alignment:.leading,spacing:14) {
                                            Avatar(person:person,size:library.value.largeCards ? 88 : 68)
                                            Text(person.name).font(.title2.bold()).multilineTextAlignment(.leading).foregroundStyle(Palette.ink)
                                            if !library.value.calmMode && !type.isAccessibilitySize && !person.note.isEmpty { Text(person.note).font(.body).foregroundStyle(Palette.ink).lineLimit(2).multilineTextAlignment(.leading) }
                                        }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityLabel(person.name + ", " + L("Details and reminders"))
                                    Button { calling.dial(person.phone,demonstration:library.demonstration) } label: { Label(L("Call"),systemImage:"phone.fill") }
                                        .buttonStyle(ActionStyle()).accessibilityLabel(L("Call") + " " + person.name)
                                }.padding(20).background(.white,in:RoundedRectangle(cornerRadius:28))
                                    .overlay(RoundedRectangle(cornerRadius:28).strokeBorder(Palette.ink.opacity(0.10)))
                            }
                        }
                    }
                    Button {
                        if library.value.people.count < 4 || hasExtra { adding = true } else { upgrade = true }
                    } label: { Label(L("Add a person"),systemImage:"plus.circle.fill") }.buttonStyle(ActionStyle(primary:false))
                    if !library.value.calmMode {
                        Label(L("Apple’s Phone app handles answering and ending calls."),systemImage:"checkmark.shield").font(.body).fixedSize(horizontal:false,vertical:true)
                    }
                }
                .navigationTitle(L("Easy Call")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing) { Button { settings = true } label: { Image(systemName:"gearshape").font(.title2).frame(minWidth:48,minHeight:48) }.accessibilityLabel(L("Settings")) } }
            }.tabItem { Label(L("People"),systemImage:"person.2.fill") }.tag(0)
            NavigationStack { KeypadView() }.tabItem { Label(L("Keypad"),systemImage:"circle.grid.3x3.fill") }.tag(1)
            NavigationStack { GuideView() }.tabItem { Label(L("Help"),systemImage:"heart.text.square.fill") }.tag(2)
        }
        .sheet(isPresented:$adding) { PersonEditor(person:Person(name:"",phone:"",color:library.value.people.count)) }
        .sheet(item:$selected) { PersonDetail(person:$0) }
        .sheet(isPresented:$settings) { SettingsView() }
        .sheet(isPresented:$upgrade) { UpgradeView() }
        .alert(L("Please check"),isPresented:Binding(get:{calling.message != nil || library.error != nil},set:{if !$0 { calling.message=nil; library.error=nil }})) {
            Button(L("OK")) { calling.message=nil; library.error=nil }
        } message: { Text(calling.message ?? library.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for:.openPerson)) { notification in
            guard let text = notification.object as? String,let id = UUID(uuidString:text) else { return }
            selected = library.value.people.first{$0.id == id}; tab = 0
            UserDefaults.standard.removeObject(forKey:"pendingPerson")
        }
        .onAppear { openPendingReminder() }
        .onChange(of:scenePhase) { _,phase in if phase == .active { openPendingReminder() } }
    }
    private func openPendingReminder() {
        guard let text=UserDefaults.standard.string(forKey:"pendingPerson"),let id=UUID(uuidString:text) else{return}
        selected=library.value.people.first{$0.id == id};tab=0
        UserDefaults.standard.removeObject(forKey:"pendingPerson")
    }
}
struct KeyboardDismissToolbar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement:.keyboard) {
            Spacer()
            Button(L("Done")) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil)
            }.font(.title3.weight(.semibold)).frame(minHeight:48)
        }
    }
}

struct PersonEditor: View {
    @EnvironmentObject private var library:Library
    @Environment(\.dismiss) private var dismiss
    @State var person:Person
    @State private var picker = false
    @State private var problem:String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { picker=true } label: { Label(L("Choose from Contacts"),systemImage:"person.crop.circle.badge.plus").font(.title3).frame(minHeight:56) }
                }
                Section(L("The person")) {
                    TextField(L("Name"),text:$person.name).textContentType(.name).font(.title2).frame(minHeight:56)
                    TextField(L("Phone number"),text:$person.phone).keyboardType(.phonePad).textContentType(.telephoneNumber).environment(\.layoutDirection,.leftToRight).font(.title2).frame(minHeight:56)
                    TextField(L("A useful note (optional)"),text:$person.note,axis:.vertical).lineLimit(3...6).font(.title3)
                }
                Section {
                    Text(L("Check the number, including its country code when needed. Calling opens Apple’s Phone app.")).font(.body)
                    Button(L("Save person")) {
                        person.name=person.name.trimmingCharacters(in:.whitespacesAndNewlines)
                        person.note=String(person.note.prefix(500))
                        guard !person.name.isEmpty,let normalized=PhoneNumber.normalized(person.phone) else { problem=L("Enter a name and a valid phone number."); return }
                        person.phone=normalized
                        if library.upsert(person) { dismiss() } else { problem=library.error }
                    }.buttonStyle(ActionStyle())
                }.listRowBackground(Color.clear)
            }.scrollContentBackground(.hidden).background(Palette.cream).scrollDismissesKeyboard(.interactively)
                .navigationTitle(L("Add or edit a person")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button(L("Cancel")) { dismiss() }.frame(minHeight:48) }
                    KeyboardDismissToolbar()
                }
                .sheet(isPresented:$picker) { ContactPicker { selected in var updated=selected; updated.id=person.id; updated.color=person.color; updated.note=person.note; person=updated } }
                .alert(L("Please check"),isPresented:Binding(get:{problem != nil},set:{if !$0 { problem=nil }})) { Button(L("OK")) { problem=nil } } message:{ Text(problem ?? "") }
        }
    }
}

struct PersonDetail: View {
    var person:Person
    @EnvironmentObject private var library:Library
    @EnvironmentObject private var calling:Calling
    @EnvironmentObject private var purchases:Purchases
    @Environment(\.dismiss) private var dismiss
    @State private var edit=false
    @State private var remove=false
    @State private var reminder=false
    @State private var upgrade=false
    @State private var copied=false
    private var current:Person { library.value.people.first{$0.id == person.id} ?? person }
    var body: some View {
        NavigationStack {
            Page {
                Avatar(person:current,size:116)
                Text(current.name).font(.largeTitle.bold())
                Text(current.phone).font(.title2.monospacedDigit()).environment(\.layoutDirection,.leftToRight).textSelection(.enabled)
                if !current.note.isEmpty { Text(current.note).font(.title2).padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:22)) }
                Button { calling.dial(current.phone,demonstration:library.demonstration) } label: { Label(L("Call"),systemImage:"phone.fill") }.buttonStyle(ActionStyle())
                Button { calling.dial(current.phone,demonstration:library.demonstration,faceTime:true) } label: { Label(L("FaceTime Audio"),systemImage:"waveform") }.buttonStyle(ActionStyle(primary:false))
                Button { if purchases.unlocked || library.value.trialActive(start:purchases.trialStart,now:Date()) { reminder=true } else { upgrade=true } } label: { Label(L("Remind me to call"),systemImage:"bell.badge") }.buttonStyle(ActionStyle(primary:false))
                ForEach(library.value.reminders.filter{$0.personID == person.id && $0.date > Date()}.sorted{$0.date < $1.date}) { item in
                    HStack {
                        Label(item.date.formatted(date:.abbreviated,time:.shortened),systemImage:"bell")
                        Spacer()
                        Button(L("Cancel reminder")) {
                            let before=library.value; library.value.reminders.removeAll{$0.id == item.id}
                            if library.save() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:[item.id.uuidString]) } else { library.value=before }
                        }.frame(minHeight:48)
                    }.font(.body)
                }
                Button { UIPasteboard.general.string=current.phone; copied=true } label: { Label(L(copied ? "Number copied" : "Copy number"),systemImage:"doc.on.doc") }.buttonStyle(ActionStyle(primary:false))
                HStack {
                    Button(L("Edit")) { edit=true }.frame(minWidth:80,minHeight:56)
                    Spacer()
                    Button(L("Remove"),role:.destructive) { remove=true }.frame(minWidth:80,minHeight:56)
                }.font(.title3)
            }.navigationTitle(L("Person")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button(L("Done")) { dismiss() }.frame(minHeight:48) } }
                .sheet(isPresented:$edit) { PersonEditor(person:current) }
                .sheet(isPresented:$reminder) { ReminderView(person:current) }
                .sheet(isPresented:$upgrade) { UpgradeView() }
                .confirmationDialog(L("Remove this person from Easy Call?"),isPresented:$remove,titleVisibility:.visible) {
                    Button(L("Remove"),role:.destructive) { library.remove(current); if library.error == nil { dismiss() } }
                } message:{Text(L("Their entry in Apple Contacts will not change. Their call reminders here will be cancelled."))}
                .alert(L("Please check"),isPresented:Binding(get:{calling.message != nil},set:{if !$0 {calling.message=nil}})) { Button(L("OK")) { calling.message=nil } } message: { Text(calling.message ?? "") }
        }
    }
}

struct KeypadView: View {
    @EnvironmentObject private var library:Library
    @EnvironmentObject private var calling:Calling
    @Environment(\.dynamicTypeSize) private var type
    @State private var number=""
    var body: some View {
        Page {
            if !type.isAccessibilitySize { SectionTitle(title:"A number to call",subtitle:"Take your time. Check the number, then tap Call.") }
            HStack {
                TextField(L("Phone number"),text:$number).keyboardType(.phonePad).font(.largeTitle.monospacedDigit()).accessibilityIdentifier("dial-number")
                Button { if !number.isEmpty {number.removeLast()} } label:{Image(systemName:"delete.left").font(.title2).frame(width:60,height:64)}.accessibilityLabel(L("Delete last digit"))
            }.padding(18).background(.white,in:RoundedRectangle(cornerRadius:22)).environment(\.layoutDirection,.leftToRight)
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:14),count:3),spacing:14) {
                ForEach(["1","2","3","4","5","6","7","8","9","+","0","⌫"],id:\.self) { digit in
                    Button {
                        if digit == "⌫" { if !number.isEmpty { number.removeLast() } }
                        else if number.count < 24 { number += digit }
                    } label:{ Text(digit).font(.system(.largeTitle,design:.rounded,weight:.semibold)).frame(maxWidth:.infinity).frame(minHeight:76).background(.white,in:RoundedRectangle(cornerRadius:22)) }
                        .foregroundStyle(Palette.ink).accessibilityLabel(digit == "⌫" ? L("Delete last digit") : digit)
                }
            }.environment(\.layoutDirection,.leftToRight)
            Button { calling.dial(number,demonstration:library.demonstration) } label:{Label(L("Call"),systemImage:"phone.fill")}.buttonStyle(ActionStyle()).disabled(PhoneNumber.normalized(number) == nil)
            Text(L("For emergency calls, use your iPhone’s Emergency screen or Phone app.")).font(.body)
        }.navigationTitle(L("Keypad")).navigationBarTitleDisplayMode(.inline)
            .toolbar { KeyboardDismissToolbar() }
    }
}

struct ReminderView:View {
    var person:Person
    @EnvironmentObject private var library:Library
    @Environment(\.dismiss) private var dismiss
    @State private var date=Date().addingTimeInterval(3600)
    @State private var saving=false
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Section { Text(person.name).font(.title.bold()); DatePicker(L("When"),selection:$date,in:Date()...).datePickerStyle(.graphical) }
                Section { Text(L("A gentle reminder opens this person’s card. It never places a call automatically.")) }
                Section {
                    Button(L("Save reminder")) { Task { await saveReminder() } }
                        .buttonStyle(ActionStyle()).disabled(saving)
                }.listRowBackground(Color.clear)
            }.scrollContentBackground(.hidden).background(Palette.cream).navigationTitle(L("Call reminder")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.cancellationAction) {Button(L("Cancel")){dismiss()}.frame(minHeight:48).disabled(saving)} }
                .alert(L("Please check"),isPresented:Binding(get:{error != nil},set:{if !$0 {error=nil}})) { Button(L("OK")){error=nil} } message:{Text(error ?? "")}
        }.interactiveDismissDisabled(saving)
    }
    @MainActor private func saveReminder() async {
        guard !saving else { return }
        saving=true; defer { saving=false }
        guard !library.demonstration else { dismiss();return }
        do {
            let item=try await Reminders.schedule(person:person,date:date)
            guard library.value.people.contains(where:{$0.id == person.id}) else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:[item.id.uuidString])
                dismiss(); return
            }
            let before=library.value
            library.value.reminders.removeAll { $0.date < Date() }
            library.value.reminders.append(item)
            if library.save() { dismiss() }
            else {
                library.value=before
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:[item.id.uuidString])
                self.error=library.error
            }
        } catch Reminders.Failure.permissionDenied {
            self.error=L("Allow notifications in iPhone Settings to receive call reminders.")
        } catch Reminders.Failure.tooMany {
            self.error=L("Cancel an existing reminder before adding another. Your reminder list is full.")
        } catch {
            self.error=L("Choose a future time and try again. The reminder was not saved.")
        }
    }
}

struct SettingsView:View {
    @EnvironmentObject private var library:Library
    @EnvironmentObject private var purchases:Purchases
    @Environment(\.dismiss) private var dismiss
    @State private var upgrade=false
    var body:some View {
        NavigationStack {
            Form {
                Section(L("Comfort")) {
                    Toggle(L("Larger contact cards"),isOn:$library.value.largeCards)
                    Toggle(L("Stronger contrast"),isOn:$library.value.highContrast)
                    Toggle(L("Calm home screen"),isOn:$library.value.calmMode)
                    Text(L("Calm mode hides notes on the home screen. Names and calling stay easy to find.")).font(.body)
                }.font(.title3)
                Section(L("Your upgrade")) {
                    Text(L(purchases.unlocked ? "Lifetime access is active" : library.value.trialActive(start:purchases.trialStart,now:Date()) ? "Your 14-day preview is active" : "Calls and four favorite people are free"))
                    Button(L("See lifetime upgrade")){upgrade=true}.frame(minHeight:56)
                    Button(L("Restore purchases")){Task{await purchases.restore()}}.frame(minHeight:56).disabled(purchases.busy)
                }
                Section {
                    NavigationLink(L("Privacy")){PrivacyView()}.frame(minHeight:56)
                    Link(L("Contact support"),destination:URL(string:"mailto:support@easycallandanswer.com?subject=Easy%20Call%20iOS")!).frame(minHeight:56)
                    Text(L("Version 1.0 • Made with care by Apps by Bros")).font(.footnote)
                }
            }.scrollContentBackground(.hidden).background(Palette.cream).navigationTitle(L("Settings"))
                .toolbar{ToolbarItem(placement:.confirmationAction){Button(L("Done")){dismiss()}.frame(minHeight:48)}}
                .onChange(of:library.value.largeCards){_,_ in library.save()}
                .onChange(of:library.value.highContrast){_,_ in library.save()}
                .onChange(of:library.value.calmMode){_,_ in library.save()}
                .sheet(isPresented:$upgrade){UpgradeView()}
                .alert(L("Purchases"),isPresented:Binding(get:{purchases.message != nil},set:{if !$0 {purchases.message=nil}})){Button(L("OK")){purchases.message=nil}} message:{Text(purchases.message ?? "")}
        }
    }
}

struct UpgradeView:View {
    @EnvironmentObject private var library:Library
    @EnvironmentObject private var purchases:Purchases
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            Page {
                Image(systemName:"sun.max.fill").font(.system(size:64)).foregroundStyle(Palette.teal).accessibilityHidden(true)
                SectionTitle(title:"More room for your people",subtitle:"One purchase. A little more peace of mind.")
                Label(L("Up to 100 favorite people"),systemImage:"person.3.fill").font(.title2)
                Label(L("Gentle call reminders"),systemImage:"bell.fill").font(.title2)
                Label(L("No subscription. No ads."),systemImage:"checkmark.seal.fill").font(.title2)
                Text(L("Calling, the keypad and four favorites stay free. Saved people always remain callable, even after a preview ends.")).font(.title3)
                if purchases.unlocked {
                    Text(L("Lifetime access is active")).font(.title2.bold())
                } else {
                    if purchases.busy { ProgressView().frame(maxWidth:.infinity).accessibilityLabel(L("Purchases")) }
                    if purchases.trialStart == nil, purchases.trialProduct != nil {
                        Button(L("Try extras free for 14 days")) {
                            Task { await purchases.buy(trial:true); library.recordVisit() }
                        }.buttonStyle(ActionStyle()).disabled(purchases.busy)
                        Text(L("Apple confirms a free 14-day Trial. It never renews or charges automatically. After 14 days, adding extra people and new reminders requires the lifetime upgrade.")).font(.body)
                    } else if library.value.trialActive(start:purchases.trialStart,now:Date()) {
                        Text(L("Your 14-day preview is active")).font(.title3.bold())
                        if let start=purchases.trialStart {
                            Text(L("Trial ends") + ": " + start.addingTimeInterval(14*86400).formatted(date:.abbreviated,time:.omitted))
                        }
                    } else if purchases.trialStart != nil {
                        Text(L("Your trial has ended. Calling and saved people remain free.")).font(.title3)
                    }
                    if let product=purchases.product {
                        Button {Task{await purchases.buy()}} label:{Text(L("Lifetime upgrade") + " · " + product.displayPrice)}.buttonStyle(ActionStyle()).disabled(purchases.busy)
                    } else {
                        Text(L("The store is unavailable right now. Your free calling features are ready to use."))
                        Button(L("Try store again")){Task{await purchases.refresh()}}.buttonStyle(ActionStyle(primary:false))
                    }
                    Button(L("Restore purchases")){Task{await purchases.restore()}}.buttonStyle(ActionStyle(primary:false)).disabled(purchases.busy)
                }
                Link(L("Apple standard license terms"),destination:URL(string:"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }.navigationTitle(L("Easy Call Plus")).navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.confirmationAction){Button(L("Done")){dismiss()}.frame(minHeight:48)}}
                .alert(L("Purchases"),isPresented:Binding(get:{purchases.message != nil},set:{if !$0 {purchases.message=nil}})){Button(L("OK")){purchases.message=nil}} message:{Text(purchases.message ?? "")}
        }
    }
}

struct GuideView:View {
    var body:some View {
        Page {
            SectionTitle(title:"A calmer way to call",subtitle:"Set up once, with someone you trust if you like.")
            GuideCard(icon:"phone.fill",title:"Answering and ending",body:"Easy Call opens the Phone app. Apple’s call screen answers and ends ordinary phone calls. An Answer or End button inside Easy Call would not control these calls.")
            GuideCard(icon:"rectangle.expand.vertical",title:"Make incoming calls easier to see",body:"In iPhone Settings, open Apps → Phone → Incoming Calls and choose Full Screen. Names and controls are easier to notice while your iPhone is unlocked.")
            GuideCard(icon:"accessibility",title:"Make the whole iPhone simpler",body:"Explore Settings → Accessibility → Assistive Access. Apple can simplify calls and other apps, with large controls and trusted contacts. Set it up with a trusted person and keep the exit passcode safe.")
            GuideCard(icon:"speaker.wave.2.fill",title:"Speaker and Bluetooth",body:"In Settings → Accessibility → Touch → Call Audio Routing, choose how calls use a speaker or Bluetooth headset. During a call, use Audio on Apple’s call screen to change the route.")
            GuideCard(icon:"car.fill",title:"In the car",body:"Set up your vehicle’s Bluetooth or CarPlay while parked. Use Siri or the vehicle’s own controls when driving. Easy Call does not listen in the background or add a driving screen.")
            GuideCard(icon:"hand.raised.fill",title:"Answer automatically only if you choose",body:"Apple offers Auto-Answer Calls under Call Audio Routing. It can answer unexpected callers too. Leave it off unless you understand the trade-off; Easy Call never enables it.")
            Link(destination:URL(string:"https://support.apple.com/guide/assistive-access-iphone/welcome/ios")!) {Label(L("Apple’s accessibility guide"),systemImage:"arrow.up.right.square")}.buttonStyle(ActionStyle(primary:false))
        }.navigationTitle(L("Help")).navigationBarTitleDisplayMode(.inline)
    }
}
struct GuideCard:View {
    var icon:String;var title:String;var bodyText:String
    init(icon:String,title:String,body:String){self.icon=icon;self.title=title;self.bodyText=body}
    var body:some View {
        VStack(alignment:.leading,spacing:16){
            Image(systemName:icon).font(.largeTitle).foregroundStyle(Palette.teal).accessibilityHidden(true)
            Text(L(title)).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(L(bodyText)).font(.title3).fixedSize(horizontal:false,vertical:true)
        }.padding(24).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:26))
    }
}
struct PrivacyView:View {
    var body:some View {
        Page {
            SectionTitle(title:"Your people stay yours",subtitle:"No account. No ads. No tracking SDKs.")
            Text(L("Easy Call keeps the favorite names, numbers, optional photos, notes and reminders you choose on this device. It does not upload them to our servers or read your call history. Device backups may include this data according to your Apple settings.")).font(.title3)
            Text(L("The system Contacts picker shares only the entry you choose. Notifications are optional and requested only when you create a reminder. A contact’s name may appear on your lock screen in a reminder; your iPhone notification preview settings control this.")).font(.title3)
            Text(L("Apple processes purchases and calls use your carrier or FaceTime. Easy Call does not record calls or use your microphone. If you email support, we receive the information you send. Avoid including private contact information.")).font(.title3)
            Text(L("Remove people in their detail screen to delete their saved data and reminders. Deleting the app removes its local storage; manage any device backups through Apple. Privacy questions: support@easycallandanswer.com.")).font(.title3)
            Text("2026-10-08").font(.footnote)
        }.navigationTitle(L("Privacy"))
    }
}
