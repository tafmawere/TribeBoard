//
//  FamilyView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Family list screen showing all demo family members
struct FamilyView: View {
    @StateObject private var viewModel: FamilyViewModel
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @State private var selectedMember: FamilyMemberDisplay?
    @State private var showingFamilySettings = false
    @State private var showingAddMember = false
    
    init(viewModel: FamilyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Family name header (editable for admins)
                if viewModel.isAdmin {
                    familyNameHeader
                }
                
                // Demo hint
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Demo family — can be removed later")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, viewModel.isAdmin ? 0 : 8)
                    
                    // Family members grid
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(viewModel.familyMembers) { member in
                                MemberCardView(member: member)
                                    .onTapGesture {
                                        selectedMember = member
                                    }
                            }
                            
                            // Add member card (admin only)
                            if viewModel.isAdmin {
                                addMemberCard
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Family")
            .toolbar {
                if viewModel.isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingFamilySettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
        .sheet(item: $selectedMember) { member in
            MemberProfileView(member: member, viewModel: viewModel)
        }
        .sheet(isPresented: $showingFamilySettings) {
            FamilySettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddMember) {
            AddFamilyMemberView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadFamilyMembers()
        }
    }
    
    // MARK: - Family Name Header
    
    private var familyNameHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.familyName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(viewModel.familyMembers.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingFamilySettings = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Add Member Card
    
    private var addMemberCard: some View {
        Button(action: {
            showingAddMember = true
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Text("Add Member")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Invite family")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
