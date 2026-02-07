//
//  AddFamilyMemberView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Add family member view for inviting new members
struct AddFamilyMemberView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var memberName: String = ""
    @State private var memberPhone: String = ""
    @State private var memberRole: FamilyRole = .observer
    @State private var isParent: Bool = false
    @State private var showingAddConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Member Information") {
                    TextField("Full Name", text: $memberName)
                        .textContentType(.name)
                    
                    TextField("Phone Number (Optional)", text: $memberPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    
                    Toggle("Parent/Guardian", isOn: $isParent)
                }
                
                Section("Role") {
                    Picker("Select Role", selection: $memberRole) {
                        Text("Observer").tag(FamilyRole.observer)
                        Text("Driver").tag(FamilyRole.driver)
                        Text("Admin").tag(FamilyRole.admin)
                    }
                    .pickerStyle(.segmented)
                    
                    // Role description
                    Text(roleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Permissions Preview") {
                    ForEach(getCapabilities(), id: \.self) { capability in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(capability)
                                .font(.subheadline)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingAddConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Add Family Member")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(memberName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Add Member", isPresented: $showingAddConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    addMember()
                }
            } message: {
                Text("Add \(memberName) to your family as \(memberRole.displayName)?")
            }
        }
    }
    
    private var roleDescription: String {
        switch memberRole {
        case .driver:
            return "Can create and drive runs, track all family runs"
        case .observer:
            return "Can view and track all family runs"
        case .admin:
            return "Full access: can manage family, create/drive runs, and change settings"
        }
    }
    
    private func getCapabilities() -> [String] {
        var capabilities = ["Can create runs"]
        
        switch memberRole {
        case .driver:
            capabilities.append("Can start/drive runs")
            capabilities.append("Can track runs")
            if isParent {
                capabilities.append("Can manage family")
                capabilities.append("Can cancel/reassign runs")
            }
        case .observer:
            capabilities.append("Can track runs")
            if isParent {
                capabilities.append("Can manage family")
                capabilities.append("Can cancel/reassign runs")
            }
        case .admin:
            capabilities.append("Can start/drive runs")
            capabilities.append("Can track runs")
            capabilities.append("Can manage family")
            capabilities.append("Can cancel/reassign runs")
        }
        
        return capabilities
    }
    
    private func addMember() {
        let phone = memberPhone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : memberPhone
        viewModel.addFamilyMember(
            name: memberName,
            phone: phone,
            role: memberRole,
            isParent: isParent
        )
        dismiss()
    }
}
