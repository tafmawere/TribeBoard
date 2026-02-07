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
    
    init(viewModel: FamilyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Demo hint
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Demo family — can be removed later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
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
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Family")
            .sheet(item: $selectedMember) { member in
                MemberProfileView(member: member, viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadFamilyMembers()
            }
        }
    }
}
