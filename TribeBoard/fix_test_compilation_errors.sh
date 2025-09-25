#!/bin/bash

echo "🔧 Fixing test compilation errors..."

# Fix NavigationTab references in test files
echo "Fixing NavigationTab references..."

# Update NavigationComponentsUnitTests.swift
sed -i '' 's/NavigationTab\.home/NavigationTab.dashboard/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/NavigationTab\.shopping/NavigationTab.messages/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/"Home"/"Dashboard"/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/"Shopping"/"Messages"/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/"house"/"house"/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/"cart"/"message"/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/"cart.fill"/"message.fill"/g' TribeBoardTests/NavigationComponentsUnitTests.swift
sed -i '' 's/"bus"/"car"/g' TribeBoardTests/NavigationComponentsUnitTests.swift

# Update NavigationItemTests.swift
sed -i '' 's/NavigationTab\.home/NavigationTab.dashboard/g' TribeBoardTests/NavigationItemTests.swift
sed -i '' 's/NavigationTab\.shopping/NavigationTab.messages/g' TribeBoardTests/NavigationItemTests.swift
sed -i '' 's/"Home"/"Dashboard"/g' TribeBoardTests/NavigationItemTests.swift
sed -i '' 's/"Shopping"/"Messages"/g' TribeBoardTests/NavigationItemTests.swift
sed -i '' 's/"house"/"house"/g' TribeBoardTests/NavigationItemTests.swift
sed -i '' 's/"cart"/"message"/g' TribeBoardTests/NavigationItemTests.swift
sed -i '' 's/"cart.fill"/"message.fill"/g' TribeBoardTests/NavigationItemTests.swift

echo "✅ NavigationTab references fixed"

# Fix RunStop.StopType references
echo "Fixing RunStop.StopType references..."
sed -i '' 's/\.pickup/.home/g' TribeBoardTests/SchoolRunViewsEnvironmentObjectIntegrationTests.swift
sed -i '' 's/\.dropoff/.school/g' TribeBoardTests/SchoolRunViewsEnvironmentObjectIntegrationTests.swift
sed -i '' 's/\.pickup/.home/g' TribeBoardTests/SchoolRunViewsEnvironmentObjectTests.swift
sed -i '' 's/\.dropoff/.school/g' TribeBoardTests/SchoolRunViewsEnvironmentObjectTests.swift

echo "✅ RunStop.StopType references fixed"

# Fix ScheduledSchoolRun initializer calls
echo "Fixing ScheduledSchoolRun initializer calls..."
sed -i '' 's/date: Date(),/scheduledDate: Date(), scheduledTime: Date(),/g' TribeBoardTests/SchoolRunViewsEnvironmentObjectIntegrationTests.swift
sed -i '' 's/date: Date(),/scheduledDate: Date(), scheduledTime: Date(),/g' TribeBoardTests/SchoolRunViewsEnvironmentObjectTests.swift

echo "✅ ScheduledSchoolRun initializer calls fixed"

# Fix UserProfile initializer calls (remove phoneNumber parameter)
echo "Fixing UserProfile initializer calls..."
sed -i '' 's/, phoneNumber: "[^"]*"//g' TribeBoardTests/NavigationSafetyIntegrationTests.swift
sed -i '' 's/, phoneNumber: "[^"]*"//g' TribeBoardTests/NavigationSafetyTests.swift

echo "✅ UserProfile initializer calls fixed"

# Fix Family initializer calls (add createdByUserId parameter)
echo "Fixing Family initializer calls..."
sed -i '' 's/Family(name: "\([^"]*\)", code: "\([^"]*\)")/Family(name: "\1", code: "\2", createdByUserId: UUID())/g' TribeBoardTests/NavigationSafetyIntegrationTests.swift
sed -i '' 's/Family(name: "\([^"]*\)", code: "\([^"]*\)")/Family(name: "\1", code: "\2", createdByUserId: UUID())/g' TribeBoardTests/NavigationSafetyTests.swift

echo "✅ Family initializer calls fixed"

# Fix Membership initializer calls (remove status parameter)
echo "Fixing Membership initializer calls..."
sed -i '' 's/, status: \.active//g' TribeBoardTests/NavigationSafetyIntegrationTests.swift
sed -i '' 's/, status: \.active//g' TribeBoardTests/NavigationSafetyTests.swift

echo "✅ Membership initializer calls fixed"

# Fix SwiftDataModelValidationTests.swift optional unwrapping
echo "Fixing SwiftDataModelValidationTests.swift..."
sed -i '' 's/family\.memberships\.isEmpty/family.memberships?.isEmpty ?? true/g' TribeBoardTests/SwiftDataModelValidationTests.swift
sed -i '' 's/user\.memberships\.isEmpty/user.memberships?.isEmpty ?? true/g' TribeBoardTests/SwiftDataModelValidationTests.swift

echo "✅ SwiftDataModelValidationTests.swift fixed"

echo "🎉 All test compilation errors have been fixed!"