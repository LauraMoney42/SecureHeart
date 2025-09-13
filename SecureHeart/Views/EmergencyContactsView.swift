//
//  EmergencyContactsView.swift
//  SecureHeart
//
//  Created by Laura Money on 9/12/25.
//

import SwiftUI

struct EmergencyContactsView: View {
    @EnvironmentObject var emergencyManager: EmergencyContactsManager
    @State private var showingAddContact = false
    @State private var showingEmergencyAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if emergencyManager.contacts.isEmpty {
                    EmptyContactsView(showingAddContact: $showingAddContact)
                } else {
                    ContactsList(emergencyManager: emergencyManager)
                }
                
                EmergencyStatusCard(emergencyManager: emergencyManager)
            }
            .navigationTitle("Emergency Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddContact = true
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddContactView(emergencyManager: emergencyManager)
            }
            .alert("Emergency Alert Active", isPresented: $showingEmergencyAlert) {
                Button("Resolve") {
                    emergencyManager.resolveEmergency()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Emergency contacts have been notified. Press 'Resolve' when the situation is handled.")
            }
        }
        .onChange(of: emergencyManager.emergencyTriggered) { triggered in
            if triggered {
                showingEmergencyAlert = true
            }
        }
    }
}

struct EmptyContactsView: View {
    @Binding var showingAddContact: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Emergency Contacts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add trusted contacts who will be notified if your heart rate indicates a medical emergency.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Add Your First Contact") {
                showingAddContact = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
}

struct ContactsList: View {
    @ObservedObject var emergencyManager: EmergencyContactsManager
    @State private var editingContact: EmergencyContact?
    
    var body: some View {
        List {
            ForEach(emergencyManager.contacts) { contact in
                ContactRow(
                    contact: contact,
                    emergencyManager: emergencyManager,
                    editingContact: $editingContact
                )
            }
            .onDelete(perform: emergencyManager.deleteContact)
        }
        .sheet(item: $editingContact) { contact in
            EditContactView(contact: contact, emergencyManager: emergencyManager)
        }
    }
}

struct ContactRow: View {
    let contact: EmergencyContact
    @ObservedObject var emergencyManager: EmergencyContactsManager
    @Binding var editingContact: EmergencyContact?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.name)
                        .font(.headline)
                    
                    if contact.isPrimary {
                        Text("PRIMARY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Text(contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(contact.relationship)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let email = contact.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button("Edit") {
                    editingContact = contact
                }
                
                Button("Set as Primary") {
                    emergencyManager.setPrimaryContact(contact)
                }
                
                Button("Call", systemImage: "phone") {
                    if let phoneURL = URL(string: "tel:\(contact.phoneNumber.filter { !$0.isWhitespace })") {
                        UIApplication.shared.open(phoneURL)
                    }
                }
                
                Button("Text", systemImage: "message") {
                    if let smsURL = URL(string: "sms:\(contact.phoneNumber.filter { !$0.isWhitespace })") {
                        UIApplication.shared.open(smsURL)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmergencyStatusCard: View {
    @ObservedObject var emergencyManager: EmergencyContactsManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: emergencyManager.emergencyTriggered ? "exclamationmark.triangle.fill" : "shield.checkered")
                    .foregroundColor(emergencyManager.emergencyTriggered ? .red : .green)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(emergencyManager.emergencyTriggered ? "Emergency Active" : "Monitoring Active")
                        .font(.headline)
                        .foregroundColor(emergencyManager.emergencyTriggered ? .red : .primary)
                    
                    if let lastAlert = emergencyManager.lastEmergencyAlert {
                        Text("Last alert: \(lastAlert, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No recent alerts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if emergencyManager.emergencyTriggered {
                Button("Resolve Emergency") {
                    emergencyManager.resolveEmergency()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct AddContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var emergencyManager: EmergencyContactsManager
    
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var relationship = "Family"
    @State private var isPrimary = false
    
    let relationships = ["Family", "Friend", "Doctor", "Spouse", "Parent", "Sibling", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section("Relationship") {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { relationship in
                            Text(relationship).tag(relationship)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Priority") {
                    Toggle("Primary Contact", isOn: $isPrimary)
                    
                    if isPrimary {
                        Text("Primary contacts are notified first in emergencies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let contact = EmergencyContact(
                            name: name,
                            phoneNumber: phoneNumber,
                            email: email.isEmpty ? nil : email,
                            relationship: relationship,
                            isPrimary: isPrimary
                        )
                        emergencyManager.addContact(contact)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct EditContactView: View {
    @Environment(\.presentationMode) var presentationMode
    let contact: EmergencyContact
    @ObservedObject var emergencyManager: EmergencyContactsManager
    
    @State private var name: String
    @State private var phoneNumber: String
    @State private var email: String
    @State private var relationship: String
    @State private var isPrimary: Bool
    
    let relationships = ["Family", "Friend", "Doctor", "Spouse", "Parent", "Sibling", "Other"]
    
    init(contact: EmergencyContact, emergencyManager: EmergencyContactsManager) {
        self.contact = contact
        self.emergencyManager = emergencyManager
        self._name = State(initialValue: contact.name)
        self._phoneNumber = State(initialValue: contact.phoneNumber)
        self._email = State(initialValue: contact.email ?? "")
        self._relationship = State(initialValue: contact.relationship)
        self._isPrimary = State(initialValue: contact.isPrimary)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section("Relationship") {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { relationship in
                            Text(relationship).tag(relationship)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Priority") {
                    Toggle("Primary Contact", isOn: $isPrimary)
                    
                    if isPrimary {
                        Text("Primary contacts are notified first in emergencies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedContact = contact
                        updatedContact.name = name
                        updatedContact.phoneNumber = phoneNumber
                        updatedContact.email = email.isEmpty ? nil : email
                        updatedContact.relationship = relationship
                        updatedContact.isPrimary = isPrimary
                        
                        emergencyManager.updateContact(updatedContact)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

#Preview {
    EmergencyContactsView()
        .environmentObject(EmergencyContactsManager())
}
