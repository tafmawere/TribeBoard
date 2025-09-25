#!/bin/bash

echo "🔧 Comprehensive test compilation fix..."

# Fix all NavigationTab references across all test files
echo "Fixing NavigationTab references in all test files..."

# Replace .home with .dashboard
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/NavigationTab\.home/NavigationTab.dashboard/g' {} \;
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/\.home/.dashboard/g' {} \;

# Replace .shopping with .messages
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/NavigationTab\.shopping/NavigationTab.messages/g' {} \;
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/\.shopping/.messages/g' {} \;

# Fix display names
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/"Home"/"Dashboard"/g' {} \;
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/"Shopping"/"Messages"/g' {} \;

# Fix icon names
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/"cart"/"message"/g' {} \;
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/"cart.fill"/"message.fill"/g' {} \;

echo "✅ NavigationTab references fixed"

# Fix UserProfile initializer calls - remove the custom initializer calls
echo "Fixing UserProfile initializer calls..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/UserProfile(name: "[^"]*", email: "[^"]*")/UserProfile(displayName: "Test User", appleUserIdHash: "test123hash")/g' {} \;

echo "✅ UserProfile initializer calls fixed"

# Fix Family initializer calls - ensure they have createdByUserId
echo "Fixing Family initializer calls..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/Family(name: "\([^"]*\)", code: "\([^"]*\)")/Family(name: "\1", code: "\2", createdByUserId: UUID())/g' {} \;

echo "✅ Family initializer calls fixed"

# Fix Membership initializer calls - remove status parameter
echo "Fixing Membership initializer calls..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/, status: \.active//g' {} \;

echo "✅ Membership initializer calls fixed"

# Fix RunStop.StopType references
echo "Fixing RunStop.StopType references..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/\.pickup/.home/g' {} \;
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/\.dropoff/.school/g' {} \;

echo "✅ RunStop.StopType references fixed"

# Fix ScheduledSchoolRun initializer calls
echo "Fixing ScheduledSchoolRun initializer calls..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/date: Date(),/scheduledDate: Date(), scheduledTime: Date(),/g' {} \;

echo "✅ ScheduledSchoolRun initializer calls fixed"

# Fix SwiftData model optional unwrapping
echo "Fixing SwiftData model optional unwrapping..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/\.memberships\.isEmpty/\.memberships?.isEmpty ?? true/g' {} \;

echo "✅ SwiftData model optional unwrapping fixed"

# Add @MainActor to test methods that need it
echo "Adding @MainActor annotations where needed..."
find TribeBoardTests -name "*.swift" -exec sed -i '' 's/func test\([^(]*\)() {/@MainActor func test\1() {/g' {} \;

echo "✅ @MainActor annotations added"

echo "🎉 Comprehensive test compilation fix complete!"